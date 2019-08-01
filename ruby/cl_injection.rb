require 'opencl_ruby_ffi'
require 'tmpdir'

kernel_name = :test_kernel

src_read = <<EOF
//__attribute__((vec_type_hint(size_t)))
__attribute__((reqd_work_group_size(1,1,1)))
__kernel void #{kernel_name}(global uint *a) {
    const uint i = get_work_dim();
    a[0] = i;
}
EOF

puts src_read

$device = OpenCL::platforms::first::devices::first

$context = OpenCL::create_context($device)

program = $context.create_program_with_source(src_read)

program.build#( options: "-cl-opt-disable" )

p program.kernels

Dir.mktmpdir("bin_kernel") { |d|
  Dir::chdir(d)
  bin_path = "program.bin"
  File::open(bin_path, "wb") { |f|
    f.write program.binaries.first[1]
  }
  puts `ocloc disasm -file #{bin_path} -device kbl -dump ./ -patch /home/videau/dev/intel-graphics-compiler/IGC/AdaptorOCL/ocl_igc_shared/executable_format/`
  puts "------------------"
  puts File::read("#{kernel_name}_KernelHeap.asm")
  puts "------------------"
  p File::read("#{kernel_name}_DynamicStateHeap.bin", mode: "rb")
  puts "------------------"
  p File::read("#{kernel_name}_SurfaceStateHeap.bin", mode: "rb")
  puts "------------------"
  puts File::read("PTM.txt")
  puts "------------------"
  puts `ocloc asm -out #{bin_path}.new -device kbl -dump ./`
  puts "------------------"
  program_new, _ = $context.create_program_with_binary($context.devices, [File::read("#{bin_path}.new", mode: "rb")])
  program_new.build
  p program_new.kernels
}

