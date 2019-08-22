def bench_mem_kernel(context,queue, global_size, unroll_factor, high_level_type, vector_length, address_space_qualifier, local_size= 32, subgroup_size=16, repetition_lauch=20)

  s = Struct.new(:type, :byte)
  babel=  {"int" =>  s.new("int",2),
           "float" => s.new("sfloat", 2),
           "double" => s.new("float",4) }

  # Compute array and size of the array
  h_a = NArray.public_send(babel[high_level_type].type, global_size*vector_length)

  # Create opencl kernel
  opencl_type= high_level_type
  if vector_length != 1
      opencl_type += vector_length.to_s
  end

  src_read = <<EOF
__attribute__((intel_reqd_sub_group_size(#{subgroup_size})))
__kernel void icule(#{address_space_qualifier} #{opencl_type} * restrict a, #{address_space_qualifier} #{opencl_type} * restrict b) {
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

  return bytes_transfered.to_f / elapsed_time
end
