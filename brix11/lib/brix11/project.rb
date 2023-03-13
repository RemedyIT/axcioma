#--------------------------------------------------------------------
# @file    project.rb
# @author  Martin Corino
#
# @brief   MPC project type support for scaffolding tool brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/system'
require 'brix11/process'

module BRIX11
  module Project
    BASEDIR = 'projects'

    MWC_CMD = 'mwc.pl'
    MPC_CMD = 'mpc.pl'

    class << self
    private
      def registry
        @registry ||= {}
      end

      def mwc
        @mwc ||= MWC_CMD
      end

      def mpc
        @mpc ||= MPC_CMD
      end

      def set_mpc_path(p)
        @mwc = File.join(p, MWC_CMD)
        @mpc = File.join(p, MPC_CMD)
      end
    end

    def self.mpc_path=(p)
      set_mpc_path(p)
    end

    def self.mwc_cmd
      mwc
    end

    def self.mpc_cmd
      mpc
    end

    def self.register(type, handler)
      registry[type.to_sym] = handler
    end

    def self.valid_type?(type)
      registry.has_key?(type.to_sym)
    end

    def self.handler(type, compiler=nil)
      BRIX11.log_fatal("Unknown project type [#{type}]") unless registry.has_key?(type.to_sym)
      registry[type.to_sym].new(type, compiler)
    end

    def self.describe_each
      if block_given?
        registry.sort {|(t1,h1),(t2,h2)|
          t1.to_s <=> t2.to_s
        }.each {|type,handler|
          compilers = if handler.const_defined?(:COMPILERS)
                        handler::COMPILERS.sort {|(t1,h1),(t2,h2)|
                          t1.to_s <=> t2.to_s
                        }.collect {|k,v|
                          v == handler::COMPILERS.default ? "#{k}*" : k.to_s
                        }
                      else
                        ''
                      end
          yield(type, compilers, handler.const_defined?(:DESCRIPTION) ? handler::DESCRIPTION : '')
        }
      end
    end

    class Compiler

      attr_reader :id

      def initialize(id)
        @id = id
      end

      def filter(_verbosity)
        BRIX11.log_fatal('Missing compiler output filter')
      end

      def mpc_args
        []
      end

      def build_args
        []
      end

    end

    class Handler

      attr_reader :type

      def self.compiler(id)
        ccklass = if const_defined?(:COMPILERS)
                    if id
                      self::COMPILERS.has_key?(id.to_sym) ? self::COMPILERS[id.to_sym] : nil
                    else
                      self::COMPILERS.default
                    end
                  else
                    nil
                  end
        BRIX11.log(3, "compiler handler #{ccklass.inspect} selected")
        ccklass ? ccklass.new(id) : nil
      end

      def initialize(type, compiler_id)
        @type = type
        @compiler = self.class.compiler(compiler_id) || BRIX11.log_fatal("Unknown compiler #{compiler_id}")
      end

      def compiler
        @compiler ? self.class::COMPILERS.invert[@compiler.class] : nil
      end

      def clean(*args)
        raise Command::CmdError, "#{self.class.name}\#clean not implemented"
      end

      def build(*args)
        raise Command::CmdError, "#{self.class.name}\#build not implemented"
      end

      def project_exists?(*args)
        raise Command::CmdError, "#{self.class.name}\#project_exists? not implemented"
      end

      def make_files
        raise Command::CmdError, "#{self.class.name}\#make_files not implemented"
      end

      def generate(opts={}, cmdargv=[])
        runopts = {}
        return false unless argv = base_mpc_args(opts, runopts, cmdargv)
        runopts[:capture] = :all if block_given?
        argv << runopts unless runopts.empty?
        argv << Proc.new if block_given?
        ok, rc = Exec.runcmd(*argv)
        BRIX11.log_warning("#{self.type}\#generate failed with exitcode #{rc}") unless ok
        ok
      end

    protected

      def base_mpc_args(opts, runopts, cmdargv)
        argv = Exec.mswin? ? ['perl'] : []
        # determine if we have a path and project, path only, project only or none
        path = opts.delete(:project)
        if project = opts.delete(:subprj)
          # path and project or project only
          unless path.nil? || File.directory?(path)
            # invalid path specified
            BRIX11.log_error("Cannot access directory #{path}")
            return nil
          end
        elsif path && File.directory?(path)
          # path only; nothing to do
        else
          # project only (or none if path == nil)
          project = path
          path = nil
        end
        if path || (project && File.directory?(project))
          runopts[:chdir] = path || project
          project = nil unless path
        end
        path ||= '.'
        mpcpath = opts.delete(:mpc_path)
        mpccmd = mpcpath ? File.join(mpcpath, MPC_CMD) : Project.mpc_cmd
        mwccmd = mpcpath ? File.join(mpcpath, MWC_CMD) : Project.mwc_cmd
        if project
          case
          when File.exist?(File.join(path, project))
            # project specifies an existing .mwc/.mpc file in <path>/
            if /\.(mwc|mpc)\Z/ =~ project
              if $1 == 'mpc'
                # .mpc file -> run mpc.pl on specified file
                cmd = mpccmd
                mwc = false
              else
                # .mwc file -> run mwc.pl on specified file
                cmd = mwccmd
                mwc = true
              end
            else
              # invalid project filename
              BRIX11.log_error("Unknown project file #{project} in #{path}")
              return nil
            end
          when File.exist?(File.join(path, "#{project}.mwc"))
            # project specifies basename of an existing .mwc file -> run mwc.pl
            project = "#{project}.mwc"
            cmd = mwccmd
            mwc = true
          when File.exist?(File.join(path, "#{project}.mpc"))
            # project specifies basename of an existing .mpc file -> run mpc.pl
            project = "#{project}.mpc"
            cmd = mpccmd
            mwc = false
          else
            # project may specify a subproject in one of the .mpc files in the
            # current directory
            unless mpcname = find_mpc_file(project)
              BRIX11.log_error("Unknown (sub-)project #{project} in #{path}")
              return nil
            end
            project = mpcname # replace project by .mpc file to generate
            cmd = mpccmd
            mwc = false
          end
        else
          # use mwc.pl in <path>/ to build all projects in that
          # directory and the tree below recursively
          mwc = true
          cmd = mwccmd
        end
        argv << cmd
        argv << '-type' << @type
        if Exec.cpu_cores > 1 && (Exec.max_cpu_cores == 0 || Exec.max_cpu_cores > 1)
          n_workers = (Exec.max_cpu_cores == 0 ? Exec.cpu_cores : Exec.max_cpu_cores)
          argv << '-workers' << n_workers unless cmdargv.any? { |arg| arg == '-workers' }
          if mpc_wrkdir_ix = cmdargv.find_index('-workers_dir')
            mpc_wrkdir = cmdargv[mpc_wrkdir_ix+1] || '.'
          else
            mpc_wrkdir = (ENV['MPC_WORKERS_DIR'] || Sys.tempdir)
            argv << '-workers_dir' << mpc_wrkdir
          end
          mpc_wrklck = ::File.join(mpc_wrkdir, 'mpc-worker.lock')
          Sys.rm(mpc_wrklck) if ::File.exist?(mpc_wrklck)
        end

        argv.concat(extra_mpc_args)

        argv.concat(cmdargv)

        run_env = opts.delete(:env)
        runopts[:env] = run_env if run_env
        runopts[:overwrite_env] = opts.delete(:overwrite_env)

        opts.each do |opt, val|
          case val
          when true
            argv << "-#{opt}"
          when String
            argv << "-#{opt}" << val
          when Array
            val.each {|ve| argv << "-#{opt}" << ve }
          when Hash
            unless val.empty?
              argv << "-#{opt}" << %Q{#{val.collect {|k,v| "#{k}=#{v}"}.join(',')}}
            end
          end
        end
        argv << project if project

        argv
      end

      def extra_mpc_args
        @compiler.mpc_args
      end

      def is_mpc_project?(name, mpcpath)
        list_mpc_projects(mpcpath).has_key?(name)
      end

      def find_mpc_file(name, mpcpath = '.')
        list_mpc_projects(mpcpath)[name]
      end

      def list_mpc_projects(path)
        (File.file?(path) ? [path] : Dir[File.join(path, '*.mpc')]).collect do |fmpc|
          parse_mpc_file(fmpc)
        end.inject({}) {|reg, subreg| reg.merge!(subreg); reg }
      end

      def parse_mpc_file(file)
        base_name = File.basename(file, '.*')
        ptable = {}
        IO.foreach(file) do |ln|
          if /\A\s*project\s*\((.*)\)/ =~ ln
            convert = !ln.index('*').nil?
            prj = $1.strip.sub(/\A\*\Z/, base_name)
            prj.sub!(/\A\*/) { |_| base_name+'_' }
            prj.sub!(/\*\Z/) { |_| '_'+base_name }
            prj.sub!('*', "_#{base_name}_")
            prj.gsub!(/(\A|[^a-zA-Z0-9])?([a-zA-Z0-9])([a-zA-Z0-9]*)/) { |_| $1+$2.upcase+$3 } if convert
            ptable[prj] = file
          end
        end
        ptable
      end

    end # Handler
  end # Project
end # BRIX11

require 'brix11/projects/filters/ridl'
require 'brix11/projects/filters/tao_idl'
Dir.glob(File.join(BRIX11::BRIX11_BASE_ROOT, 'lib', 'brix11', BRIX11::Project::BASEDIR, '*.rb')).each do |p|
  require "brix11/projects/#{File.basename(p)}"
end
