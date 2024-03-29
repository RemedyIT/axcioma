#--------------------------------------------------------------------
# @file    gnuace.rb
# @author  Martin Corino
#
# @brief   MPC 'gnuace' project type support for brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/formatter'
require 'brix11/projects/compilers/gnu'
require 'brix11/projects/filters/gnumake'

module BRIX11
  module Project
    class GnuMake < Handler
      ID = 'gnumake'
      BUILDTOOL = 'make'
      BUILDTOOL_VERSION = (Sys.expand("#{BUILDTOOL} --version").chomp.split("\n").first || '').match(/[\d.]+/).to_s
      PROJECTNAME = 'GNUmakefile'
      DESCRIPTION = 'GNU Make makefiles'
      COMPILERS = Hash[
        gnu: GNUCompiler
      ]
      COMPILERS.default = GNUCompiler

      def default_prj_type
        BUILDTOOL_VERSION >= '4.0' ? 'gnuace' : 'gnuautobuild'
      end
    end

    class GnuAce < GnuMake
      ID = 'gnuace'

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
        argv = base_build_arg(project, path, cmdargv, runopts) << 'realclean' << runopts
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

        run_env = options[:env]
        runopts[:env] = run_env if run_env
        runopts[:overwrite_env] = options[:overwrite_env]

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
          File.directory?(path) && File.file?(File.join(path, project ? "#{PROJECTNAME}.#{project}" : PROJECTNAME))
        elsif project
          File.file?("#{PROJECTNAME}.#{project}") ||
            (File.directory?(project) && File.file?(File.join(project, PROJECTNAME)))
        else
          File.file?(PROJECTNAME)
        end
      end

    protected

      def init_filter(verbosity, logfile = nil)
        tools = []
        tools << Filter::GNUMakefile.new(verbosity)
        tools << @compiler.filter(verbosity)
        tools << Filter::RIDLCompiler.new(verbosity)
        tools << Filter::TAO_IDLCompiler.new(verbosity)
        tools << Filter::GMake.new(verbosity)
        flt = BRIX11::Formatter::Filter.new(tools, verbosity)
        flt = Formatter::Tee.new(logfile, flt) if logfile
        flt
      end

      def base_build_arg(project, path, cmdargv, opts)
        argv = [BUILDTOOL]
        argv.concat(cmdargv)
        argv << (opts[:debug] ? 'debug=1' : 'debug=0')
        # GNU make 4.0 has a way to control output during parallel execution
        # https://www.gnu.org/software/make/manual/html_node/Parallel-Output.html#Parallel-Output
        argv << '-j' << (Exec.max_cpu_cores > 0 ? Exec.max_cpu_cores : Exec.cpu_cores) << '-Orecurse' if Exec.cpu_cores > 1 && BUILDTOOL_VERSION >= '4.0'
        argv << '--always-make' if opts[:force]
        opts[:chdir] = path if path && (project || File.directory?(path))
        if opts[:chdir]
          argv << '-f' << "#{PROJECTNAME}.#{project}" if project
        elsif project
          if File.directory?(project)
            opts[:chdir] = project
          else
            argv << '-f' << "#{PROJECTNAME}.#{project}"
          end
        end
        argv.concat(@compiler.build_args)
        argv
      end
    end # Handler

    register(GnuMake::ID, GnuMake)
    register(GnuAce::ID, GnuAce)
  end # Project
end # BRIX11
