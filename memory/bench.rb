#!/usr/bin/env ruby

gem 'opencl_ruby_ffi', '=1.3.4'
require 'opencl_ruby_ffi'
require 'narray_ffi'
require_relative 'monkey'
require_relative 'mem'

device = OpenCL::platforms::last::devices::first
context = OpenCL::create_context(device)
queue = context.create_command_queue(device, :properties => OpenCL::CommandQueue::PROFILING_ENABLE)
oversubscribed_ratio=2**8

# 7 Thread * Number of EU * overhead number
global_size=7*device.eu_number*oversubscribed_ratio

puts "Number of subslice: #{device.subslice_number}"
puts "global size: #{global_size}"
puts "ν: #{device.freq_mhz} mhz"

puts "_ type  B/clk/subslice %peak"

result_tree = Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }

for address_space_qualifier in ["global","local"]
for bench in ["read","write","copy"]
  r = ["",0]
  for type in ["int","float", "double"]
  for vector in  [1,2,4]
  unroll_factor = Hash.new(1)
  unroll_factor[bench] = 1
  bw_per_second = bench_mem_kernel(context,queue,global_size, unroll_factor, type,vector, address_space_qualifier)

  bw_per_clk = 1000*bw_per_second / device.freq_mhz
  bw_per_clk_per_subslice = bw_per_clk / device.subslice_number
  peak = 100 * bw_per_clk_per_subslice / 64

  if r[1] < bw_per_second
    r = ["#{address_space_qualifier} #{bench}  #{'%.2f' % bw_per_clk_per_subslice} #{'%.2f' % peak}% (#{type}#{vector}) ",bw_per_second]
  end

  end
  end
puts r[0]
end
end



