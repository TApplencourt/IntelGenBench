#!/usr/bin/env ruby
require 'opencl_ruby_ffi'
require 'erb'
require 'fileutils'
require 'logger'
require 'open3'
require 'tmpdir'

#                           _
# |\/|  _  ._  |   _       |_) _. _|_  _ |_  o ._   _
# |  | (_) | | |< (/_ \/   |  (_|  |_ (_ | | | | | (_|
#                     /                             _|
class OpenCL::Device
    def eu_number
        @eu_number ||= self.max_compute_units
    end

    def subslice_number
        @subslice_number ||= eu_number / 8
    end

    def freq_mhz
        min = `cat /sys/class/drm/card0/gt_min_freq_mhz`.strip.to_i
        max = `cat /sys/class/drm/card0/gt_max_freq_mhz`.strip.to_i
        boost = `cat /sys/class/drm/card0/gt_boost_freq_mhz`.strip.to_i

        $logger.debug("#{self.name} min freqency #{min} mhz")
        $logger.debug("#{self.name} max freqency #{max} mhz")
        $logger.debug("#{self.name} boost freqency #{boost} mhz")

        if min != max or max != boost
            $logger.warn("#{self.name} may power throttle")
        end
        @freq_mhz ||= max
    end
end


$type_to_bytes = {:f => 4,
                  :df => 8 }

#
#___                                          
#  |  ._  o _|_ o  _. | o _   _. _|_ o  _  ._  
# _|_ | | |  |_ | (_| | | /_ (_|  |_ | (_) | | 
#                                              
$logger = Logger.new(STDOUT)

# Mode supported for template
$l_suported_mode = ["RAR","RAW", "independent"]

# Instruction supported for template
T = Struct.new(:flops, :n_register, :n_register_input, :pattern)
$l_suported_inst = {"mad" => T.new(2,4, 3, [".0<1>", ".0<2;1>", ".0<2;1>", ".0<1>"]), 
                    "add" => T.new(1,3,2, [".0<1>", ".0<2;2,1>",".0<2;2,1>"]),
                    "math.sqt" => T.new(1,2,1, [".0<1>", ".0<2;2,1>"]),
                    "math.inv" => T.new(1,2,1, [".0<1>", ".0<2;2,1>"]) }
                    
# OpenCL usefull global variable
$dev = OpenCL.platforms.first.devices.first
$logger.info("Device: #{$dev.name}")
$dev.freq_mhz
$context = OpenCL.create_context([$dev])
$queue = $context.create_command_queue($dev, :properties => [ OpenCL::CommandQueue::PROFILING_ENABLE] )

#  _                            
# |_    ._   _ _|_ o  _  ._   _ 
# | |_| | | (_  |_ | (_) | | _> 
#                               
class DataDependency 
    @@suported_flavor =  ["RAR","RAW", "independent"]

    def initialize(raw)
        @raw = raw
    end 

    def flavor_dep
      case @raw
      when /(\D+)(\d+)/
        [$1, $2.to_i]
      when /(\D+)/
        [$1, 1]
      else
        raise "unexpected pattern"
      end 
    end 

    def flavor
        f =self.flavor_dep[0]
        unless @@suported_flavor.include? f
            puts "#[f} not supported yet"
            puts "Choose one from #{@@suported_flavor}"
            exit
        end 
        f   
    end

    def n_dep
        self.flavor_dep[1]
    end

    def to_s
        @raw.to_s
    end
end

# Will execute a command, and logger the result
# used to execut 'ocloc'
def exec_and_log(cmd)
    $logger.debug(cmd)
    stdout, stderr, status = Open3.capture3(cmd)
    $logger.debug(stdout.strip) unless stdout.empty?
    $logger.warn(stderr.strip) unless stderr.empty?
end

def parse_input(i, f:)
  
    begin 
      i_p = eval(i)
    rescue NameError => e
      puts "#{i} Not a valide ruby expresion" 
      exit
    end

    unless i_p.kind_of? Enumerable
        i_p = [ i_p ] 
    end
    i_p.map(&f)
end

class KernelFactory

   def initialize(inst, datatype, mode, simd_size, n_inner, n_outer)

      @inst = inst
      @inst_o = $l_suported_inst[@inst]
      @datatype = datatype
      
      @mode = mode.flavor 
      @n_dep = mode.n_dep

      @simd_size = simd_size
      @n_inner = n_inner
      @n_outer = n_outer

      @grb_inst = [1,@simd_size*$type_to_bytes[@datatype] / 32].max

   end

   def modoff(i)
      offset =  3 + @inst_o.n_register_input*@grb_inst
      n0 = 127 - offset
      n1 = n0 - n0 % @grb_inst
      offset + i%n1
   end

   def inst_lines(l_idx)
     # A lot to bigest in the next line
     # inst_o.pattern is a the regioning need for the instruction:
     #     For example (.0<1>f for the output, or .0<2;2,1> for input)
     # We zip this regioning with the list of register we want to use
     # Then we print the final register r3.0<2;2,1> for example
     "#{@inst} (#{@simd_size}|M0) " + @inst_o.pattern.zip(l_idx).map{|i,j| "r#{j}#{i}:#{@datatype}"}.join(' ')
   end 

   def template_rendered
      $logger.info("grb_inst: #{@grb_inst}")

      @inst_o = $l_suported_inst[@inst]
      @inst = @inst.gsub('_','.') 
      $logger.info("n_inner: #{@n_inner}")
      $logger.info("n_outer: #{@n_outer}")
      $logger.info("n_det: #{@n_dep}")

      template_path="#{__dir__}/kernel.asm.erb"
      template = File.read(template_path)
      rendered =  ERB.new(template,nil, '-').result(binding)

   end

   def kernel

      # General
      bin_name="parsed"
      kernel_name="f0"
      asm_name="#{kernel_name}_KernelHeap"
      cl_name="kernel"
      cl_path="#{__dir__}/kernel.cl"

      Dir.mkdir("work_dir") unless File.exists?("work_dir")
      program,status  = Dir.chdir("work_dir") do
         $logger.debug("Removing old binary and dump folder")
         FileUtils.rm("#{bin_name}.bin", force: true)
         FileUtils.rm_r("dump", force: true)

         exec_and_log("ocloc compile -file #{cl_path} -device skl")
         exec_and_log("ocloc disasm -file #{cl_name}_Gen9core.bin -device skl")

         $logger.debug("Generating assembly")

         File.write("dump/#{asm_name}.asm", self.template_rendered)
         $logger.add(-1, self.template_rendered)

         exec_and_log("ocloc asm -out #{bin_name}.bin -device skl")

         $logger.debug("Creating the binary")
         $context.create_program_with_binary([$dev], [File::read("#{bin_name}.bin", mode: "rb")] )
      end
      program.build
      $logger.debug(program.build_log)
      program.create_kernel(kernel_name)
   end

    def flops
        (@n_inner * @n_outer)*$l_suported_inst[@inst].flops
    end

    def instructions_count
      if @n_outer > 1
        t = [@n_inner,1].max*(@n_outer+2)
      else
        t = [@n_inner,1].max*@n_outer
      end
      $logger.debug("instructions_count :#{t}")
      t
    end

end

class Bench

   def initialize(inst, datatype, mode, simd_size, n_inner, n_outer, n_global)
       @global_work_size = n_global
       @local_work_size = simd_size

       $logger.debug("global_work_size: #{@global_work_size}")
       $logger.debug("local_work_size: #{@local_work_size}")

       @kernelFactory = KernelFactory.new(inst, datatype, mode, simd_size, n_inner, n_outer)
   end

   def flops
       @kernelFactory.flops*@global_work_size
   end

   def threads
        # Because local_work_group == simd_size
        t = @global_work_size/@local_work_size
        $logger.debug("threads: #{t}")
        t
   end

   def instructions_count
       @kernelFactory.instructions_count * self.threads
   end

   def eu_used
        [$dev.eu_number, self.threads].min
   end

   def best_time

      kernel = @kernelFactory.kernel

      a = 1.times.map { |i|
         event = $queue.enqueue_ndrange_kernel(kernel, [@global_work_size], local_work_size: [@local_work_size])
         OpenCL.wait_for_events(event)
         start = event.profiling_command_start
         stop = event.profiling_command_end
         t = stop-start
         $logger.info("Iterations #{i}:  #{t} ns")
         t
      }

      $logger.info("Min #{a.min} ns")
      a.min
   end
end


# Will generate the asm correcponding to the parameter,
# And then execute it, and return the time
def bench(inst, datatype, mode, simd_size, n_global, n_inner, n_outer)
    Bench.new inst, datatype, mode, simd_size, n_inner, n_outer, n_global
end 

def ns_to_clk(t,ndigits=0)
    c = t*1E-9 * $dev.freq_mhz*1E6
    return c.round(ndigits)
end
