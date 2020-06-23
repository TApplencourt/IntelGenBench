require 'tmpdir'

class NArray
    def byte_size
        return self.size * self.element_size
    end
end

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
        # Force the kernel to be build before used
        #@kernels_lazy ||= begin
            begin
                self.build(options: "-cl-opt-disable")
            rescue
                p self.build_log
                exit
            end
            self.kernels
        #end
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
      puts 'Disamble'
      `ocloc disasm -file #{bin_path} -device kbl -dump ./ > /dev/null`
      exit if $?.exitstatus != 0
      puts "ok"

      # Patch the assembly
      File::open(asm_path, "r+") { |f|
          src_asm = f.read.gsub(/(^\s+send\s.*\s+sends\s.*?$\n)/m, '\1'*unroll_factor["copy"]) # Duplicate everything between a load and store
                          .gsub(/(^\s+send\s.*\n)/,                '\1'*unroll_factor["read"])  # Duplicate all the loads
                          .gsub(/(^\s+sends\s.*\n)/,               '\1'*unroll_factor["write"]) # Dupliace all the stores

          f.seek(0, IO::SEEK_SET)
          f.write(src_asm)
      }

      # Reasamble it
      puts "assembe"
      `ocloc asm -out #{bin_path_new} -device skl -dump ./`
      exit if $?.exitstatus != 0
      puts "ok"
      return binary
      # Create the new program
      #program_new, _ = OpenCL.create_program_with_binary(self,
      #                                                   devices,
      #                                                   [File::read("#{bin_path_new}", mode: "rb")])
      #return program_new
    }
  end
end
