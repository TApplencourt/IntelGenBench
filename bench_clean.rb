#!/usr/bin/env ruby

require 'opencl_ruby_ffi'
require 'narray_ffi'

require 'tmpdir'
require 'erb'

class OpenCL::Device
    def eu_number
        @eu_number ||= self.max_compute_units
    end

    def subslice_number
        @subslice_number ||= eu_number / 8
    end

    def freq_mhz
        @freq_mhz ||= `cat /sys/class/drm/card0/gt_max_freq_mhz`.strip.to_i
    end
end


class OpenCL::Program
    def kernels
        # Force the kernel to be constructed before used
        @kernels ||= begin
            begin
                self.build #(options: "-cl-opt-disable")
            rescue
                p self.build_log
                exit
            end
            OpenCL.create_kernels_in_program( self )
        end
    end
end

class OpenCL::Context
  def create_program_with_source_and_assembly(src_read, src_asm, print_orig_asm = false)

    # Create the original binary
    program = OpenCL.create_program_with_source(self,src_read)

    bin_path = "program.bin"
    bin_path_new = "#{bin_path}.new"
    asm_path="#{program.kernels.first.name}_KernelHeap.asm"

    # Create a temporary dir to save all the intermediate data
    Dir.mktmpdir("bin_kernel") { |d|
      d = "bin_kernel"
      Dir::chdir(d)
      
      # Write original binary
      File::open(bin_path, "wb") { |f| f.write program.binaries.first[1] }

      # Disamble it
      puts `ocloc disasm -file #{bin_path} -device kbl -dump ./`
      exit if $?.exitstatus != 0

      # Patch the assembly
      File::open(asm_path, "r") { |f| puts f.read} if print_orig_asm
      File::open(asm_path, "w") { |f| f.write src_asm }
      
      # Reasamble it
      puts `ocloc asm -out #{bin_path_new} -device kbl -dump ./`
	  exit if $?.exitstatus != 0

      # Create the new program
       program_new, _ = OpenCL.create_program_with_binary(self, 
                                                         devices, 
                                                         [File::read("#{bin_path_new}", mode: "rb")])
      return program_new
    }
  end
end


src_template = <<EOF
__attribute__((intel_reqd_sub_group_size(16)))
__kernel void icule(global double *a) {
    const int i = get_global_id(0);
    a[i] = a[i] + i;
}
EOF

asm_template = <<EOF
(W)      mov (8|M0)               r2.0<1>:ud    r0.0<1;1,0>:ud
(W)      or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x4C0:uw         {Switch}
(W)      mul (1|M0)               r3.0<1>:d     r5.3<0;1,0>:d     r2.1<0;1,0>:d    {Compacted}
(W)      mov (8|M0)               r127.0<1>:ud  r2.0<8;8,1>:ud                   {Compacted}
         add (16|M0)              r6.0<1>:d     r3.0<0;1,0>:d     r1.0<16;16,1>:uw
         add (16|M0)              r8.0<1>:d     r6.0<8;8,1>:d     r4.0<0;1,0>:d    {Compacted}
         shl (16|M0)              r10.0<1>:d    r8.0<8;8,1>:d     3:w
         mov (8|M0)               r26.0<1>:df   r8.0<8;8,1>:d
         mov (8|M8)               r28.0<1>:df   r9.0<8;8,1>:d
         add (16|M0)              r12.0<1>:d    r10.0<8;8,1>:d    r5.2<0;1,0>:d    {Compacted}
<% UNROLL_FACTOR["copy"].times do  %>
  <% UNROLL_FACTOR["read"].times do  %>
         send (16|M0)             r14:w    r12     0xC         0x4405C00  //    wr:2+?, rd:4, Untyped Surface Read msc:28, to #0
  <% end %>
         mov (8|M0)               r22.0<2>:d    r14.0<8;8,1>:d
         mov (8|M8)               r24.0<2>:d    r15.0<8;8,1>:d
         mov (8|M0)               r22.1<2>:d    r16.0<8;8,1>:d
         mov (8|M8)               r24.1<2>:d    r17.0<8;8,1>:d
         add (8|M0)               r30.0<1>:df   r22.0<4;4,1>:df   r26.0<4;4,1>:df
         add (8|M8)               r32.0<1>:df   r24.0<4;4,1>:df   r28.0<4;4,1>:df
         mov (8|M0)               r18.0<1>:d    r30.0<2;1,0>:d
         mov (8|M0)               r20.0<1>:d    r30.1<2;1,0>:d
         mov (8|M8)               r19.0<1>:d    r32.0<2;1,0>:d
         mov (8|M8)               r21.0<1>:d    r32.1<2;1,0>:d
  <% UNROLL_FACTOR["write"].times do  %>
         sends (16|M0)            null:w   r12     r18     0x10C       0x4025C00  //    wr:2+4, rd:0, Untyped Surface Write msc:28, to #0
  <% end %>
<% end %>
(W)      send (8|M0)              null     r127    0x27        0x2000010  {EOT} //    wr:1+?, rd:0, fc: 0x10
EOF

device = OpenCL::platforms::last::devices::first
context = OpenCL::create_context(device)
# 7 threads * #eu * work_group_size * number of byte per elements
LOCAL_SIZE=64 # Lower doesn't work
GLOBAL_SIZE=7*device.eu_number*LOCAL_SIZE * 8

# 0 Read, 1 Write, 2 Copy
type_computation = 1

UNROLL_FACTOR = Hash.new(1)
case type_computation
when 0
    UNROLL_FACTOR["read"] = 1000
when 1
    UNROLL_FACTOR["write"] = 1000
when 2
    UNROLL_FACTOR["copy"] = 1000
end

REPETITION_LAUCH=20


# Load kernel and assembly template
h_a = NArray.float(GLOBAL_SIZE)
h_a.each { |x| x=0 }

# Compute size of the array
h_a_byte_size = h_a.size * h_a.element_size

# Apply template
src_read = ERB.new(src_template).result()
asm_read = ERB.new(asm_template).result()

# Create and build the program 
#program = context.create_program_with_source(src_read)
program = context.create_program_with_source_and_assembly(src_read, asm_read, true)

# Create the queue
queue = context.create_command_queue(device, :properties => OpenCL::CommandQueue::PROFILING_ENABLE)

# Create kernel
kernel = program.create_kernel(program.kernels.first.name)

# Create device buffer and fill it with 0
p "Before"
p h_a
d_a = context.create_buffer(h_a_byte_size)
queue.enqueue_write_buffer(d_a,h_a)
queue.finish

# Launching the kernel kernel
elapsed_time = 2**64 - 1
REPETITION_LAUCH.times do 
  event = kernel.enqueue_with_args(queue, [GLOBAL_SIZE], d_a, local_work_size: [LOCAL_SIZE])
  OpenCL::wait_for_events([event])
  elapsed_time = [elapsed_time, event.profiling_command_end -  event.profiling_command_start].min
end 
queue.enqueue_read_buffer(d_a,h_a)
queue.finish

# Display result
p "After"
p h_a
# Compute summary
bytes_transfered = h_a_byte_size * ( UNROLL_FACTOR["write"]+ UNROLL_FACTOR["read"] ) * UNROLL_FACTOR["copy"]

bw_per_second =  bytes_transfered.to_f / elapsed_time
bw_per_clk = 1000*bw_per_second / device.freq_mhz
bw_per_clk_per_subslice = bw_per_clk / device.subslice_number
peak = 100 * bw_per_clk_per_subslice / ( UNROLL_FACTOR["copy"]==1 ? 64 : 128 )

puts "Number of subslice: #{device.subslice_number}"
puts "memory_footprint: #{h_a_byte_size  / 1E3} KB"

puts "Unroll factor:"
puts "  Read:  #{UNROLL_FACTOR["read"]}"
puts "  Write: #{UNROLL_FACTOR["write"]}"
puts "  Copy:  #{UNROLL_FACTOR["copy"]}"

puts "ν: #{device.freq_mhz} mhz"
puts "Δt: #{elapsed_time} ns"
puts "bw: #{'%.2f' % bw_per_second} GB/s"
puts "  : #{'%.2f' % bw_per_clk} B/clk"
puts "  : #{'%.2f' % bw_per_clk_per_subslice} B/clk/susblice"
puts "peak: #{'%.2f' % peak} %"
