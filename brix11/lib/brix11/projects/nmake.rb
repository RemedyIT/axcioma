#--------------------------------------------------------------------
# @file    nmake.rb
# @author  Marijke Hengstmengel
#
# @brief   Base for MPC 'nmake' project type support for brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/formatter'
require 'brix11/projects/filters/nmake'
require 'brix11/projects/compilers/msc'

module BRIX11

  module Project

    # NMAKE specific MSC derivatives for use with MPC

    class MSCNMake64 < MSCCompiler

      def platform
        'x64'
      end

    end

    class MSCNMake64VC14 < MSCNMake64

      def version
        'vc14nmake'
      end

    end

    class MSCNMake64VC141 < MSCNMake64

      def version
        'vs2017nmake'
      end

    end

    class MSCNMake32 < MSCCompiler

      def platform
        'Win32'
      end

    end

    class MSCNMake32VC14 < MSCNMake32

      def version
        'vc14nmake'
      end

    end

    class MSCNMake32VC141 < MSCNMake32

      def version
        'vs2017nmake'
      end

    end

    class NMake < Handler

      ID = 'nmake'
      DESCRIPTION = 'Microsoft NMAKE Makefiles'
      BUILDTOOL = 'nmake'
      PROJECTNAME = 'Makefile'
      PROJECTEXT = '.mak'
      COMPILERS = Hash[
        vc14: MSCNMake64VC14,
        vc141: MSCNMake64VC141,
        vc14x64: MSCNMake64VC14,
        vc141x64: MSCNMake64VC141,
        vc14x32: MSCNMake32VC14,
        vc141x32: MSCNMake32VC141,
      ]
      COMPILERS.default = MSCNMake64VC141

      def initialize(type, compiler_id)
        super
        @type = 'nmake'
      end

      def make_files
        PROJECTNAME
      end

      def clean(cmdargv, *args)
        options = case args.last
                   when Hash, OpenStruct
                     args.pop
                   else
                     {}
                   end
        project = args.shift
        path = args.shift
        unless project_exists?(project, path)
          msg = 'Unknown project'
          msg << " #{project}" if project
          msg << " in #{path}" if path
          BRIX11.log_error(msg)
          return false
        end
        runopts = {}
        runopts[:capture] = :all if block_given?
        runopts[:filter] = init_filter(options[:verbose] || 1, options[:logfile]) unless options[:make][:noredirect]
        runopts[:debug] = options[:make][:debug]
        argv = base_build_arg(project, path,cmdargv, runopts) << 'realclean' << runopts
        argv << Proc.new if block_given?
        ok, rc = Exec.runcmd(*argv)
        BRIX11.log_warning("#{self.type}\#clean failed with exitcode #{rc}") unless ok
        ok
      end

      def build(cmdargv, *args)
        options = case args.last
                  when Hash, OpenStruct
                    args.pop
                  else
                    {}
                  end

        project = args.shift
        path = args.shift
        unless project_exists?(project, path)
          msg = 'Unknown project'
          msg << " #{project}" if project
          msg << " in #{path}" if path
          BRIX11.log_error(msg)
          return false
        end
        runopts = {}
        runopts[:force] = options[:force]
        runopts[:capture] = :all if block_given?
        runopts[:filter] = init_filter(options[:verbose] || 1, options[:logfile]) unless options[:make][:noredirect]
        runopts[:debug] = options[:make][:debug]
        argv = base_build_arg(project, path, cmdargv, runopts) << runopts
        argv << Proc.new if block_given?
        ok, rc = Exec.runcmd(*argv)
        BRIX11.log_warning("#{self.type}\#build failed with exitcode #{rc}") unless ok
        ok
      end

      def project_exists?(*args)
        project = args.shift
        path = args.shift
        if path
          File.directory?(path) && File.file?(File.join(path, project ? "#{PROJECTNAME}.#{project}#{PROJECTEXT}" : PROJECTNAME))
        elsif project
          File.file?("#{PROJECTNAME}.#{project}#{PROJECTEXT}") ||
           (File.directory?(project) && File.file?(File.join(project, PROJECTNAME)))
        else
          File.file?(PROJECTNAME)
        end
      end

    protected

      def init_filter(verbosity, logfile = nil)
        tools = []
        tools << Filter::Makefile.new(verbosity)
        tools << @compiler.filter(verbosity)
        tools << Filter::RIDLCompiler.new(verbosity)
        tools << Filter::TAO_IDLCompiler.new(verbosity)
        tools << Filter::NMake.new(verbosity)
        flt = BRIX11::Formatter::Filter.new(tools, verbosity)
        flt = Formatter::Tee.new(logfile, flt) if logfile
        flt
      end

      def extra_mpc_args
        super.concat(%W(-value_template platforms="#{@compiler.platform}" -base #{@compiler.version}))
      end

      def base_build_arg(project, path, cmdargv, opts)
        argv = [BUILDTOOL]
        argv.concat(cmdargv)
        argv << '--always-make' if opts[:force]

        opts[:chdir] = path if path && (project || File.directory?(path))
        if opts[:chdir]
          argv << '-f' << "#{PROJECTNAME}.#{project}#{PROJECTEXT}" if project
        elsif project
          if File.directory?(project)
            opts[:chdir] = project
          else
            argv << '-f' << "#{PROJECTNAME}.#{project}#{PROJECTEXT}"
          end
        end
        argv << 'NO_EXTERNAL_DEPS=1'
        argv << "CFG=#{@compiler.platform} #{opts[:debug] ? 'Debug' : 'Release'}"
        argv.concat(@compiler.build_args)
        argv
      end

    end # Handler

    register(NMake::ID, NMake)

  end # Project

end # BRIX11
