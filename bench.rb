#!/usr/bin/env ruby

require 'opencl_ruby_ffi'
require 'narray_ffi'
require_relative 'monkey'

s = Struct.new(:type, :byte)
BABEL_NARRAY =  {"int" =>  s.new("int",2),
                 "float" => s.new("sfloat", 2),
                 "double" => s.new("float",4) }

def bench(context,queue, global_size, unroll_factor, high_level_type, vector_length = 1, local_size= 32, subgroup_size=16, repetition_lauch=20)

  # Compute array and size of the array
  h_a = NArray.public_send(BABEL_NARRAY[high_level_type].type, global_size*vector_length)

  # Create opencl kernel
  opencl_type= high_level_type
  if vector_length != 1
      opencl_type += vector_length.to_s
  end
  src_read = <<EOF
__attribute__((intel_reqd_sub_group_size(#{subgroup_size})))
__kernel void icule(global #{opencl_type} * restrict a, global #{opencl_type} * restrict b) {
    const int i = get_global_id(0);
    a[i] = b[i];
}
EOF

  bytes_transfered = h_a.byte_size * ( unroll_factor["write"] + unroll_factor["read"] ) * unroll_factor["copy"]

  # Create and build the program 
  #program = context.create_program_with_source(src_read)
  program = context.patch_and_create_program_with_source(src_read, unroll_factor)

  # Create kernel
  kernel = program.create_kernel(program.kernels_lazy.first.name)

  # Create device buffer and fill it with 0
  d_a = context.create_buffer(h_a.byte_size)
  d_b = context.create_buffer(h_a.byte_size)
  event = queue.enqueue_fill_buffer(d_b, OpenCL::Int1.new(0))
  OpenCL::wait_for_events([event])

  # Launching the kernel kernel
  elapsed_time = 2**64 - 1
  repetition_lauch.times do 
   event = kernel.enqueue_with_args(queue, [global_size], d_a, d_b, local_work_size: [local_size])
   OpenCL::wait_for_events([event])
   elapsed_time = [elapsed_time, event.profiling_command_end -  event.profiling_command_start].min
  end 
  queue.enqueue_read_buffer(d_a,h_a)
  queue.finish

  return bytes_transfered, elapsed_time
end 




device = OpenCL::platforms::last::devices::first
context = OpenCL::create_context(device)
queue = context.create_command_queue(device, :properties => OpenCL::CommandQueue::PROFILING_ENABLE)

oversubscribed_ratio=64*8

# 7 Thread * Number of EU * overhead number
global_size=7*device.eu_number*oversubscribed_ratio

puts "Number of subslice: #{device.subslice_number}"
puts "global size: #{global_size}"
puts "ν: #{device.freq_mhz} mhz"

puts "_ type  B/clk/subslice %peak"
for bench, type, vector in ["read","write","copy"].product(["int","float", "double"], 
                                                           [1,2,4])

  unroll_factor = Hash.new(1)
  unroll_factor[bench] = 1000
  bytes_transfered, elapsed_time = bench(context,queue,global_size, unroll_factor, type,vector)

  # Compute summary
  bw_per_second =  bytes_transfered.to_f / elapsed_time
  bw_per_clk = 1000*bw_per_second / device.freq_mhz
  bw_per_clk_per_subslice = bw_per_clk / device.subslice_number
  peak = 100 * bw_per_clk_per_subslice / 64

  puts "#{bench} #{type}#{vector} #{'%.2f' % bw_per_clk_per_subslice} #{'%.2f' % peak}%"
end
