#--------------------------------------------------------------------
# @file    msbuild.rb
# @author  Marijke Hengstmengel
#
# @brief   MSBuild Solution project type support for brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/formatter'
require 'pathname'
require 'brix11/projects/filters/msbuild'
require 'brix11/projects/compilers/msc'

module BRIX11

  module Project

    # MSBuild solution specific IDL compiler filter

    module Filter

      class MSBuildIDL
        include Formatter::Filter::FilterMethods

        TOOL_PATTERN = /(\d+\>)?CustomBuild:.*\Z/
        COMPILE_PATTERN = /Invoking\s+".*(?<tool>(ridlc|tao_idl))\s+on\s+(?<name>(\S+))".*\Z/


        # override
        def initialize(verbosity)
          @pattern = TOOL_PATTERN
          @action = 'Generating'
          @tool_verbosity = 2
          @verbosity = verbosity
          @ridl_filter = Filter::RIDLCompiler.new(verbosity)
          @taoidl_filter = Filter::TAO_IDLCompiler.new(verbosity)
        end

        # override
        def output=(out)
          super
          @ridl_filter.output = out
          @taoidl_filter.output = out
        end

        # override
        def report_tool(match)
          @last_output_category = nil
          output.println match.string if verbosity > tool_verbosity
        end

        # override
        def filter_output(s)
          if _m = COMPILE_PATTERN.match(s)
            @tool = _m[:tool]
            if verbosity >= tool_verbosity
              if verbosity == tool_verbosity
                output.println bold(tool_action), ": #{_m.names.include?('name') ? _m[:name] : '(unknown)'}"
              else
                output.print(bold(tool_action), ': ')
                output.println _m.string
              end
            end
            return true
          end
          # filter other output
          @ridl_filter.filter_output(s) || @taoidl_filter.filter_output(s)
        end

      end # MSBuildIDL

    end # Filter

    # MSBuild solution specific MSC derivatives

    class MSBuildCompiler < MSCCompiler

      class Filter < MSCCompiler::Filter

        TOOL_PATTERN = /(\d+\>)?((ClCompile:)|(Link:)).*\Z/
        CMD_PATTERN = /(((?<tool>([Cc][Ll]\.exe))\s((?<cmdarg>(.*))\s+([\S]+\.)(c|C|cc|CC|cxx|CXX|cpp|CPP|S|asm)\s+.*))|((?<tool>([Ll][Ii][Nn][Kk]\.exe))\s.*))\Z/
        COMPILE_PATTERN = /\A\s+(?<name>(\S+\.(c|C|cc|CC|cxx|CXX|cpp|CPP|S|asm)))\Z/
        LINK_PATTERN = /.*\.vcxproj\s+->\s+(?<name>(.*\.(dll|exe)))\Z/
        OUTPUT_PATTERNS = [
            # compile messages
            [:error,      /\A(\s*\d+\>)?(?<name>\S.*)\((?<line>\d+)\):\s+[Ee]rror\s+C\d+:\s+(?<desc>.*)\s+\[\S+\]\Z/],
            [:error,      /\A(\s*\d+\>)?(?<name>\S.*)\((?<line>\d+)\):\s+[Ff]atal\s+error\s+C\d+:\s+(?<desc>.*)\s+\[\S+\]\Z/],
            [:warning,    /\A(\s*\d+\>)?(?<name>\S.*)\((?<line>\d+)\):\s+[Ww]arning\s+C\d+:\s+(?<desc>.*)\s+\[\S+\]\Z/],
            # generic
            [:error,      /\A(\s*\d+\>)?(?<name>\S.*):\((?<line>\d+)\0:(\d+:)? (?<desc>.*)\s+\[\S+\]\Z/],
            [:info,       /\A(\s*\d+\>)?(?<name>\S.*):\s*(?<desc>.*):$/],
            [:ignore,     /Compiling\.\.\..*/],
            [:ignore,     /ResourceCompile:.*/],
            [:ignore,     /.*rc\.exe.*/],
            [:ignore,     /\A(\s*\d+\>)?c1xx\s+:\s+.*\Z/]
        ]

        # override
        def initialize(verbosity)
          super
          @pattern = TOOL_PATTERN
        end

        # override
        def report_tool(match)
          @last_output_category = nil
          @link_start = (match.string =~ /link/i ? true : false)
          @action = @link_start ? 'Linking' : 'Compiling'
          @tool = @link_start ? 'link.exe' : 'cl.exe'
          output.println match.string if verbosity > tool_verbosity
        end

        # override
        def filter_output(s)
          _m = if @action == 'Compiling'
                 COMPILE_PATTERN.match(s)
               else
                 LINK_PATTERN.match(s)
               end
          if _m
            if verbosity >= tool_verbosity
              if verbosity == tool_verbosity
                output.println bold(tool_action), ": #{_m.names.include?('name') ? _m[:name] : '(unknown)'}"
              else
                output.print(bold(tool_action), ': ')
                output.println _m.string
              end
            end
            return true
          end
          if _m = CMD_PATTERN.match(s)
            @tool = _m[:tool]
            output.println _m.string if verbosity > tool_verbosity
            return true
          end
          # filter other output
          return super
        end

        # override
        def output_patterns
          OUTPUT_PATTERNS+Project::Filter::MSBuildFile::IGNORE_PATTERNS
        end

      end # Filter

      # override
      def filter(verbosity)
        Filter.new(verbosity)
      end

    end # MSBuildCompiler

    class MSBuildCompiler64 < MSBuildCompiler

      def platform
        'x64'
      end

    end # MSBuildCompiler64

    class MSBuildVC14x64 < MSBuildCompiler64

      def version
        'v140'
      end

    end # MSBuildVC14x64

    class MSBuildVC141x64 < MSBuildCompiler64

      def version
        'v141'
      end

    end # MSBuildVC141x64

    class MSBuildCompiler32 < MSBuildCompiler

      def platform
        'Win32'
      end

    end # MSBuildCompiler32

    class MSBuildVC14x32 < MSBuildCompiler32

      def version
        'v140'
      end

    end # MSBuildVC14x32

    class MSBuildVC141x32 < MSBuildCompiler32

      def version
        'v141'
      end

    end # MSBuildVC141x32

    class MSBuildSolution < Handler

      BUILDTOOL = 'msbuild'
      PROJECTEXT = '.sln'

      def make_files
        '*.{sln,vcxproj,sdf}'
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
        argv = base_build_arg(project, path,cmdargv, runopts) << '/t:Clean' << runopts
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
          File.directory?(path) && File.file?(File.join(path, project ? "#{project}#{PROJECTEXT}" : sln_for_dir(path)))
        elsif project
          if File.file?("#{project}#{PROJECTEXT}")
            true
          elsif File.directory?(project)
            # if only a path, take last path name part and use this as sln name, also replacing '-' with '_'
            File.file?(File.join(project, sln_for_dir(project)))
          else
            false
          end
        else
          # no path or project , look for sln file with same name as dir
          File.file?(File.join(Dir.pwd, sln_for_dir(Dir.pwd)))
        end
      end

    protected

      def extra_mpc_args
        super.concat(%W(-value_template platforms="#{@compiler.platform}" -value_template PlatformToolset=#{@compiler.version}))
      end

      def sln_for_dir(path)
        dir_name = Pathname.new(path).basename()
        # mpc creates sln files with name of dir, but replaces '-' with '_'
        sln_name = dir_name.to_s.gsub('-','_')
        sln_name << PROJECTEXT
        unless File.exist?(File.join(path, sln_name))
          # incase file does not exist look for a single .sln file in path
          prj_list = Dir.glob(File.join(path, "*#{PROJECTEXT}"))
          BRIX11.log_fatal("Specify project to build. Multiple projects (.sln) available at location #{path}.") if prj_list.size > 1
          if prj_list.size == 1
            sln_name = File.basename(prj_list.shift)
          else
            sln_name = ''
          end
        end
        sln_name
      end

      def init_filter(verbosity, logfile = nil)
        tools = []
        tools << Filter::MSBuildFile.new(verbosity)
        tools << @compiler.filter(verbosity)
        tools << Filter::MSBuildIDL.new(verbosity)
        tools << Filter::TAO_IDLCompiler.new(verbosity)
        tools << Filter::MSBuild.new(verbosity)
        flt = BRIX11::Formatter::Filter.new(tools, verbosity)
        flt = Formatter::Tee.new(logfile, flt) if logfile
        flt
      end

      def base_build_arg(project, path, cmdargv, opts)
        argv = [BUILDTOOL]
        argv << "/maxcpucount#{(Exec.max_cpu_cores > 0) ? ":#{Exec.max_cpu_cores}" : ''}" if Exec.cpu_cores > 1
        argv.concat(cmdargv)
        #argv << '--always-make' if opts[:force]

        opts[:chdir] = path if path && (project || File.directory?(path))
        if opts[:chdir]
          argv << (project ? "#{project}#{PROJECTEXT}" : sln_for_dir(opts[:chdir]))
        elsif project
          if File.directory?(project)
            opts[:chdir] = project
            # Assume sln with same name as last path name part and use this as sln name, also replacing '-' with '_'
            argv << sln_for_dir(project)
          else
            argv << "#{project}#{PROJECTEXT}"
          end
        else # no project and no path look for sln file in current dir
          argv << sln_for_dir(Dir.pwd)
        end
        argv.concat(@compiler.build_args)
        argv << "/p:Configuration=#{opts[:debug] ? 'Debug' : 'Release'}"
        argv
      end

    end # MSBuildSolution

    class MSBuildVS2015 < MSBuildSolution

      ID = 'vs2015'
      DESCRIPTION = 'Microsoft Visual Studio 2015 solutions'
      COMPILERS = Hash[
        vc14: MSBuildVC14x64,
        vc14x64: MSBuildVC14x64,
        vc14x32: MSBuildVC14x32
      ]
      COMPILERS.default = MSBuildVC14x64

      def initialize(type, compiler_id)
        super
        @type = 'vc14'
      end

    protected

      # override
      def base_build_arg(project, path, cmdargv, opts)
        super << "/p:PlatformTarget=#{@compiler.platform}"
      end

    end

    register(MSBuildVS2015::ID, MSBuildVS2015)

    class MSBuildVS2017 < MSBuildSolution

      ID = 'vs2017'
      DESCRIPTION = 'Microsoft Visual Studio 2017 solutions'
      COMPILERS = Hash[
        vc141: MSBuildVC141x64,
        vc141x64: MSBuildVC141x64,
        vc141x32: MSBuildVC141x32
      ]
      COMPILERS.default = MSBuildVC141x64

      def initialize(type, compiler_id)
        super
        @type = 'vs2017'
      end

    protected

      # override
      def base_build_arg(project, path, cmdargv, opts)
        super << "/p:Platform=#{@compiler.platform}"
      end

    end

    register(MSBuildVS2017::ID, MSBuildVS2017)

  end # Project

end # BRIX11
