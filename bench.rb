#!/usr/bin/env ruby

require 'opencl_ruby_ffi'
require 'narray_ffi'

require 'tmpdir'
require 'erb'


# Create device and context
device = OpenCL::platforms::last::devices::first
context = OpenCL::create_context(device)

GLOBAL_SIZE=7*8*device.max_compute_units*64
LOCAL_SIZE=64
UNROLL_FACTOR= 1000
REPETITION_LAUCH=20





class OpenCL::Context
  def create_program_with_source_and_assembly(src_read, src_asm, print_orig_asm = false)

    # Create the original binary
    program = OpenCL.create_program_with_source(self,src_read)
    begin
      program.build #(options: "-cl-opt-disable")
    rescue
      p program.build_log
      exit
    end

    bin_path = "program.bin"
    bin_path_new = "#{bin_path}.new"
    asm_path="#{program.kernels.first.name}_KernelHeap.asm"

    # Create a temporary dir to save all the intermediate data
    Dir.mktmpdir("bin_kernel") { |d|
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

bumdle = Hash.new

# Store int 16
src_template = <<EOF
__attribute__((intel_reqd_sub_group_size(16)))
__kernel void icule(global uint *a) {
    const uint i = get_global_id(0);
    a[i] = i;
}
EOF

asm_template = <<EOF
(W)      mov (8|M0)               r2.0<1>:ud    r0.0<1;1,0>:ud
(W)      or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x4C0:uw         {Switch}
(W)      shl (1|M0)               r3.0<1>:d     r2.1<0;1,0>:d     4:w
(W)      mov (8|M0)               r127.0<1>:ud  r2.0<8;8,1>:ud                   {Compacted}
         add (16|M0)              r5.0<1>:d     r3.0<0;1,0>:d     r1.0<16;16,1>:uw
         add (16|M0)              r5.0<1>:d     r5.0<8;8,1>:d     r4.0<0;1,0>:d    {Compacted}
         shl (16|M0)              r7.0<1>:d     r5.0<8;8,1>:d     2:w
<% UNROLL_FACTOR.times do  %>
         sends (16|M0)            null:w   r7      r5      0x8C        0x4025E00  
<% end %>
(W)      send (8|M0)              null     r127    0x27        0x2000010  {EOT} //    wr:1+?, rd:0, fc: 0x10
EOF

bumdle["store_uint_16"] = {"src" => src_template,
                           "asm" => asm_template,
                           "h_a" => NArray.int(GLOBAL_SIZE)}

# Store float 16 
src_template = <<EOF
__attribute__((intel_reqd_sub_group_size(16)))
__kernel void icule(global float *a) {
    const int i = get_global_id(0);
    a[i] = i;
}
EOF

asm_template = <<EOF
(W)      mov (8|M0)               r2.0<1>:ud    r0.0<1;1,0>:ud
(W)      or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x4C0:uw         {Switch}
(W)      shl (1|M0)               r3.0<1>:d     r2.1<0;1,0>:d     5:w
(W)      mov (8|M0)               r127.0<1>:ud  r2.0<8;8,1>:ud                   {Compacted}
         add (16|M0)              r5.0<1>:d     r3.0<0;1,0>:d     r1.0<16;16,1>:uw
         add (16|M0)              r5.0<1>:d     r5.0<8;8,1>:d     r4.0<0;1,0>:d    {Compacted}
         mov (16|M0)              r7.0<1>:f     r5.0<8;8,1>:ud                   {Compacted}
         shl (16|M0)              r5.0<1>:d     r5.0<8;8,1>:d     2:w
<% UNROLL_FACTOR.times do  %>
         sends (16|M0)            null:w   r5      r7      0x8C        0x4025E00  //    wr:2+2, rd:0, Untyped Surface Write msc:30, to #0
<% end %>
(W)      send (8|M0)              null     r127    0x27        0x2000010  {EOT} //    wr:1+?, rd:0, fc: 0x10
EOF

bumdle["store_float_16"] = {"src" => src_template,
                           "asm" => asm_template,
                           "h_a" => NArray.sfloat(GLOBAL_SIZE)}


# Store float 32
src_template = <<EOF
__attribute__((intel_reqd_sub_group_size(32)))
__kernel void icule(global float *a) {
    const int i = get_global_id(0);
    a[i] = i;
}
EOF

asm_template = <<EOF
(W)      mov (8|M0)               r3.0<1>:ud    r0.0<1;1,0>:ud
(W)      or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x4C0:uw         {Switch}
(W)      mul (1|M0)               r6.0<1>:d     r8.3<0;1,0>:d     r3.1<0;1,0>:d    {Compacted}
(W)      mov (8|M0)               r127.0<1>:ud  r3.0<8;8,1>:ud                   {Compacted}
         add (16|M0)              r4.0<1>:d     r6.0<0;1,0>:d     r1.0<16;16,1>:uw
         add (16|M16)             r9.0<1>:d     r6.0<0;1,0>:d     r2.0<16;16,1>:uw
         add (16|M0)              r4.0<1>:d     r4.0<8;8,1>:d     r7.0<0;1,0>:d    {Compacted}
         add (16|M16)             r9.0<1>:d     r9.0<8;8,1>:d     r7.0<0;1,0>:d
         mov (16|M0)              r11.0<1>:f    r4.0<8;8,1>:d                    {Compacted}
         mov (16|M16)             r13.0<1>:f    r9.0<8;8,1>:d
         shl (16|M0)              r4.0<1>:d     r4.0<8;8,1>:d     2:w
         shl (16|M16)             r9.0<1>:d     r9.0<8;8,1>:d     2:w
         add (16|M0)              r4.0<1>:d     r4.0<8;8,1>:d     r8.2<0;1,0>:d    {Compacted}
         add (16|M16)             r9.0<1>:d     r9.0<8;8,1>:d     r8.2<0;1,0>:d
<% UNROLL_FACTOR.times do  %>
         sends (16|M0)            null:w   r4      r11     0x8C        0x4025E00  //    wr:2+2, rd:0, Untyped Surface Write msc:30, to #0
         sends (16|M16)           null:w   r9      r13     0x8C        0x4025E00  //    wr:2+2, rd:0, Untyped Surface Write msc:30, to #0
<% end %>
(W)      send (8|M0)              null     r127    0x27        0x2000010  {EOT} //    wr:1+?, rd:0, fc: 0x10
EOF

bumdle["store_float_32"] = {"src" => src_template,
                           "asm" => asm_template,
                           "h_a" => NArray.sfloat(GLOBAL_SIZE)}

# Store double 8
src_template = <<EOF
__attribute__((intel_reqd_sub_group_size(8)))
__kernel void icule(global double *a) {
    const int i = get_global_id(0);
    a[i] = i;
}
EOF

asm_template = <<EOF
(W)      mov (8|M0)               r2.0<1>:ud    r0.0<1;1,0>:ud
(W)      or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x4C0:uw         {Switch}
(W)      mul (1|M0)               r5.0<1>:d     r5.3<0;1,0>:d     r2.1<0;1,0>:d    {Compacted}
(W)      mov (8|M0)               r127.0<1>:ud  r2.0<8;8,1>:ud                   {Compacted}
         add (8|M0)               r3.0<1>:d     r5.0<0;1,0>:d     r1.0<8;8,1>:uw
         add (8|M0)               r3.0<1>:d     r3.0<8;8,1>:d     r4.0<0;1,0>:d    {Compacted}
         mov (8|M0)               r6.0<1>:df    r3.0<8;8,1>:d
         shl (8|M0)               r3.0<1>:d     r3.0<8;8,1>:d     3:w
         mov (8|M0)               r8.0<1>:d     r6.0<2;1,0>:d
         mov (8|M0)               r9.0<1>:d     r6.1<2;1,0>:d
         add (8|M0)               r3.0<1>:d     r3.0<8;8,1>:d     r5.2<0;1,0>:d    {Compacted}
<% UNROLL_FACTOR.times do  %>
         sends (8|M0)             null:ud  r3      r8      0x8C        0x2026C00  //    wr:1+2, rd:0, Untyped Surface Write msc:44, to #0
<% end %>
(W)      send (8|M0)              null     r127    0x27        0x2000010  {EOT} //    wr:1+?, rd:0, fc: 0x10
EOF


bumdle["store_double_8"] = {"src" => src_template,
                            "asm" => asm_template,
                            "h_a" => NArray.float(GLOBAL_SIZE)}

# Store double 16
src_template = <<EOF
__attribute__((intel_reqd_sub_group_size(16)))
__kernel void icule(global double *a) {
    const int i = get_global_id(0);
    a[i] = i;
}
EOF

asm_template = <<EOF
(W)      mov (8|M0)               r2.0<1>:ud    r0.0<1;1,0>:ud
(W)      or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x4C0:uw         {Switch}
(W)      mul (1|M0)               r3.0<1>:d     r5.3<0;1,0>:d     r2.1<0;1,0>:d    {Compacted}
(W)      mov (8|M0)               r127.0<1>:ud  r2.0<8;8,1>:ud                   {Compacted}
         add (16|M0)              r6.0<1>:d     r3.0<0;1,0>:d     r1.0<16;16,1>:uw
         add (16|M0)              r6.0<1>:d     r6.0<8;8,1>:d     r4.0<0;1,0>:d    {Compacted}
         mov (8|M0)               r12.0<1>:df   r6.0<8;8,1>:d
         mov (8|M8)               r14.0<1>:df   r7.0<8;8,1>:d
         shl (16|M0)              r6.0<1>:d     r6.0<8;8,1>:d     3:w
         mov (8|M0)               r8.0<1>:d     r12.0<2;1,0>:d
         mov (8|M0)               r10.0<1>:d    r12.1<2;1,0>:d
         mov (8|M8)               r9.0<1>:d     r14.0<2;1,0>:d
         mov (8|M8)               r11.0<1>:d    r14.1<2;1,0>:d
         add (16|M0)              r6.0<1>:d     r6.0<8;8,1>:d     r5.2<0;1,0>:d    {Compacted}
<% UNROLL_FACTOR.times do  %>
         sends (16|M0)            null:w   r6      r8      0x10C       0x4025C00  //    wr:2+4, rd:0, Untyped Surface Write msc:28, to #0
<% end %>
(W)      send (8|M0)              null     r127    0x27        0x2000010  {EOT} //    wr:1+?, rd:0, fc: 0x10
EOF

bumdle["store_double_16"] = {"src" => src_template,
                             "asm" => asm_template,
                             "h_a" => NArray.float(GLOBAL_SIZE)}


# Store double 32
src_template = <<EOF
__attribute__((intel_reqd_sub_group_size(32)))
__kernel void icule(global double *a) {
    const int i = get_global_id(0);
    a[i] = i;   
}
EOF

asm_template = <<EOF
(W)      mov (8|M0)               r3.0<1>:ud    r0.0<1;1,0>:ud
(W)      or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x4C0:uw         {Switch}
(W)      mul (1|M0)               r6.0<1>:d     r8.3<0;1,0>:d     r3.1<0;1,0>:d    {Compacted}
(W)      mov (8|M0)               r127.0<1>:ud  r3.0<8;8,1>:ud                   {Compacted}
         add (16|M0)              r4.0<1>:d     r6.0<0;1,0>:d     r1.0<16;16,1>:uw
         add (16|M16)             r9.0<1>:d     r6.0<0;1,0>:d     r2.0<16;16,1>:uw
         add (16|M0)              r4.0<1>:d     r4.0<8;8,1>:d     r7.0<0;1,0>:d    {Compacted}
         add (16|M16)             r9.0<1>:d     r9.0<8;8,1>:d     r7.0<0;1,0>:d
         mov (8|M0)               r19.0<1>:df   r4.0<8;8,1>:d
         mov (8|M8)               r21.0<1>:df   r5.0<8;8,1>:d
         shl (16|M0)              r4.0<1>:d     r4.0<8;8,1>:d     3:w
         mov (8|M16)              r23.0<1>:df   r9.0<8;8,1>:d
         mov (8|M24)              r25.0<1>:df   r10.0<8;8,1>:d
         shl (16|M16)             r9.0<1>:d     r9.0<8;8,1>:d     3:w
         mov (8|M0)               r11.0<1>:d    r19.0<2;1,0>:d
         mov (8|M0)               r13.0<1>:d    r19.1<2;1,0>:d
         mov (8|M8)               r12.0<1>:d    r21.0<2;1,0>:d
         mov (8|M8)               r14.0<1>:d    r21.1<2;1,0>:d
         add (16|M0)              r4.0<1>:d     r4.0<8;8,1>:d     r8.2<0;1,0>:d    {Compacted}
         mov (8|M16)              r15.0<1>:d    r23.0<2;1,0>:d
         mov (8|M16)              r17.0<1>:d    r23.1<2;1,0>:d
         mov (8|M24)              r16.0<1>:d    r25.0<2;1,0>:d
         mov (8|M24)              r18.0<1>:d    r25.1<2;1,0>:d
         add (16|M16)             r9.0<1>:d     r9.0<8;8,1>:d     r8.2<0;1,0>:d
<% UNROLL_FACTOR.times do  %>
         sends (16|M0)            null:w   r4      r11     0x10C       0x4025C00  //    wr:2+4, rd:0, Untyped Surface Write msc:28, to #0
         sends (16|M16)           null:w   r9      r15     0x10C       0x4025C00  //    wr:2+4, rd:0, Untyped Surface Write msc:28, to #0
<% end  %>
(W)      send (8|M0)              null     r127    0x27        0x2000010  {EOT} //    wr:1+?, rd:0, fc: 0x10

EOF

bumdle["store_double_32"] = {"src" => src_template,
                             "asm" => asm_template,
                             "h_a" => NArray.float(GLOBAL_SIZE)}

# Load float 16
src_template = <<EOF
__attribute__((intel_reqd_sub_group_size(16)))
__kernel void icule(global float *a) {
    const int i = get_global_id(0);
    a[i];
}
EOF

asm_template = <<EOF
(W)      mov (8|M0)               r2.0<1>:ud    r0.0<1;1,0>:ud
(W)      or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x4C0:uw         {Switch}
(W)      mul (1|M0)               r3.0<1>:d     r5.3<0;1,0>:d     r2.1<0;1,0>:d    {Compacted}
         add (16|M0)              r6.0<1>:d     r3.0<0;1,0>:d     r1.0<16;16,1>:uw
         add (16|M0)              r6.0<1>:d     r6.0<8;8,1>:d     r4.0<0;1,0>:d    {Compacted}
         shl (16|M0)              r6.0<1>:d     r6.0<8;8,1>:d     2:w
         add (16|M0)              r6.0<1>:d     r6.0<8;8,1>:d     r5.2<0;1,0>:d    {Compacted}
<% UNROLL_FACTOR.times do  %>
         send (16|M0)             r8:w     r6      0xC         0x4205E00  //    wr:2+?, rd:2, Untyped Surface Read msc:30, to #0
<% end %>
(W)      mov (8|M0)               r127.0<1>:ud  r2.0<8;8,1>:ud                   {Compacted}
(W)      send (8|M0)              null     r127    0x27        0x2000010  {EOT} //    wr:1+?, rd:0, fc: 0x10
EOF

bumdle["load_float_16"] = {"src" => src_template,
                           "asm" => asm_template,
                           "h_a" => NArray.sfloat(GLOBAL_SIZE)}



# Chose the benchmark
puts 'Posible argument'
puts bumdle.keys

bench_name = ARGV[0] #"store_float_32"
puts "The chosen one: #{bench_name}"
h = bumdle[bench_name]

# Load kernel and assembly template
src_template = h["src"]
asm_template = h["asm"]
h_a = h["h_a"]

# Compute size of the array
h_a_byte_size = h_a.size * h_a.element_size

# Apply template
src_read = ERB.new(src_template).result()
asm_read = ERB.new(asm_template).result()

# Create and build the program 
#program = $context.create_program_with_source(src_read)
program = context.create_program_with_source_and_assembly(src_read, asm_read, true)

begin
  program.build
rescue
  p program.build_log
  exit
end

# Create the queue
queue = context.create_command_queue(device, :properties => OpenCL::CommandQueue::PROFILING_ENABLE)

# Create kernel
kernel = program.create_kernel(program.kernels.first.name)

# Create device buffer
d_a = context.create_buffer(h_a_byte_size)

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
p h_a

# Compute summary
freq=`cat /sys/class/drm/card0/gt_max_freq_mhz`.strip.to_i
number_subslice = device.max_compute_units / 8
bytes_transfered = h_a_byte_size * UNROLL_FACTOR 
bw_per_second =  bytes_transfered.to_f / elapsed_time
bw_per_clk = 1000*bw_per_second / freq
bw_per_clk_per_subslice = bw_per_clk / number_subslice
peak = 100 * bw_per_clk_per_subslice / 64

puts "Number of subslice: #{number_subslice}"
puts "memory_footprint: #{h_a_byte_size  / 1E3} KB"
puts "unroll_factor: #{UNROLL_FACTOR}"
puts "ν: #{freq} mhz"
puts "Δt: #{elapsed_time} ns"
puts "bw: #{'%.2f' % bw_per_second} GB/s"
puts "  : #{'%.2f' % bw_per_clk} B/clk"
puts "  : #{'%.2f' % bw_per_clk_per_subslice} B/clk/susblice"
puts "peak: #{'%.2f' % peak} %"
