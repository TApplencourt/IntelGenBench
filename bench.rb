#!/usr/bin/env ruby

require 'opencl_ruby_ffi'
require 'narray_ffi'
require 'tmpdir'

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
    def kernels_lazy
        # Force the kernel to be constructed before used
        @kernels_lazy ||= begin
            begin
                self.build #(options: "-cl-opt-disable")
            rescue
                p self.build_log
                exit
            end
            self.kernels
        end
    end
end

class OpenCL::Context
  def patch_and_create_program_with_source(src_read, unroll_factor)
   

    # Create the original binary
    program = OpenCL.create_program_with_source(self,src_read)

    bin_path = "program.bin"
    bin_path_new = "#{bin_path}.new"
    asm_path="#{program.kernels_lazy.first.name}_KernelHeap.asm"

    # Create a temporary dir to save all the intermediate data
    Dir.mktmpdir("bin_kernel") { |d|
      Dir::chdir(d)
      
      # Write original binary
      File::open(bin_path, "wb") { |f| f.write program.binaries.first[1] }

      # Disamble it
      puts `ocloc disasm -file #{bin_path} -device kbl -dump ./`
      exit if $?.exitstatus != 0

      # Patch the assembly
      File::open(asm_path, "r+") { |f| 
           
          src_asm = f.read.gsub(/(^\s+send\s.*\s+sends\s.*?$\n)/m, "\\1"*unroll_factor["copy"]) # Duplicate everything between a load and store
                          .gsub(/(^\s*send\s.*\n)/, "\\1"*unroll_factor["read"])  # Duplicate all the load
                          .gsub(/(^\s*sends\s.*\n)/, "\\1"*unroll_factor["write"]) # Dupliace all the store
          f.seek(0, IO::SEEK_SET)
          f.write(src_asm)
      }

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

device = OpenCL::platforms::last::devices::first
context = OpenCL::create_context(device)
# 7 threads * #eu * work_group_size * vector_length
LOCAL_SIZE=64 
VECTOR_LENGTH=4

GLOBAL_SIZE=7*device.eu_number*LOCAL_SIZE * 4

# 0 Read, 1 Write, 2 Copy
UNROLL_FACTOR = Hash.new(1)
case ARGV[0].to_i
when 0
    UNROLL_FACTOR["read"] = 1000
when 1
    UNROLL_FACTOR["write"] = 1000
when 2
    UNROLL_FACTOR["copy"] = 1000
end

REPETITION_LAUCH=20


# Load kernel and assembly template
h_a = NArray.int(GLOBAL_SIZE*VECTOR_LENGTH)

# Compute size of the array
h_byte_size = h_a.size * h_a.element_size

# Create opencl kernel
src_read = <<EOF
__attribute__((intel_reqd_sub_group_size(16)))
__kernel void icule(global int#{VECTOR_LENGTH} * restrict a, global int#{VECTOR_LENGTH} * restrict b) {
    const int i = get_global_id(0);
    a[i] = b[i];
}
EOF

# Create and build the program 
#program = context.create_program_with_source(src_read)
program = context.patch_and_create_program_with_source(src_read, UNROLL_FACTOR)

# Create the queue
queue = context.create_command_queue(device, :properties => OpenCL::CommandQueue::PROFILING_ENABLE)

# Create kernel
kernel = program.create_kernel(program.kernels_lazy.first.name)

# Create device buffer and fill it with 0
d_a = context.create_buffer(h_byte_size)
d_b = context.create_buffer(h_byte_size)
event = queue.enqueue_fill_buffer(d_b, OpenCL::Int4.new(1,2,3,4))
OpenCL::wait_for_events([event])

# Launching the kernel kernel
elapsed_time = 2**64 - 1
REPETITION_LAUCH.times do 
  event = kernel.enqueue_with_args(queue, [GLOBAL_SIZE], d_a, d_b, local_work_size: [LOCAL_SIZE])
  OpenCL::wait_for_events([event])
  elapsed_time = [elapsed_time, event.profiling_command_end -  event.profiling_command_start].min
end 
queue.enqueue_read_buffer(d_a,h_a)
queue.finish

# Display result
p "After"
p h_a
# Compute summary
bytes_transfered = h_byte_size * ( UNROLL_FACTOR["write"] + UNROLL_FACTOR["read"] ) * UNROLL_FACTOR["copy"]
bw_per_second =  bytes_transfered.to_f / elapsed_time
bw_per_clk = 1000*bw_per_second / device.freq_mhz
bw_per_clk_per_subslice = bw_per_clk / device.subslice_number
peak = 100 * bw_per_clk_per_subslice / 64

puts "Number of subslice: #{device.subslice_number}"
puts "memory_footprint: #{2*h_byte_size  / 1E3} KB"
puts "global size: #{GLOBAL_SIZE}"
puts "local size: #{LOCAL_SIZE}"
puts "Unroll factor:"
puts "  Read:  #{UNROLL_FACTOR["read"]}"
puts "  Write: #{UNROLL_FACTOR["write"]}"
puts "  Copy:  #{UNROLL_FACTOR["copy"]}"

puts "ν: #{device.freq_mhz} mhz"
puts "Δt: #{elapsed_time} ns"
puts "bw: #{'%.2f' % bw_per_second} GB/s"
puts "  : #{'%.2f' % bw_per_clk} B/clk"
puts "  : #{'%.2f' % bw_per_clk_per_subslice} B/clk/subslice"
puts "peak: #{'%.2f' % peak} %"
