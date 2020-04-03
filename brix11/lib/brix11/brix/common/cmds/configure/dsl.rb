#--------------------------------------------------------------------
# @file    dsl.rb
# @author  Martin Corino
#
# @brief  Configure tool DSL
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module BRIX11

  module Common

    class Configure  < Command::Base

      class RCSpec

        class << self

          private

          # DSL handler for rc file toplevel block
          class DSLHandler
            def initialize(rclist, rcfile)
              @rclist = rclist
              @rcfile = rcfile
            end
            def configure(mod_id, &block)
              BRIX11.log_fatal("Duplicate module configuration for [#{mod_id}].") if @rclist.has_key?(mod_id.to_sym)
              rc = RCSpec.new(mod_id.to_sym, @rcfile, &block)
              @rclist[rc.mod_id] = rc
            end
          end # DSLHandler

          def rc_load(rclist, fname)
            begin
              BRIX11.log(2, "Loading configurerc [#{fname}]")
              DSLHandler.new(rclist, fname).instance_eval(File.read(fname), fname)
            rescue
              BRIX11.log_error("Error loading configurerc : #{$!.message}")
              $!.backtrace.find do |bt|
                file, line, _ = bt.split(':')
                if file == fname
                  BRIX11.show_msg("\t#{file}:#{line}")
                  true
                else
                  false
                end
              end
              BRIX11.log(2, $!.backtrace.join("\n"))
              BRIX11.log_fatal('Failed to configure.')
            end
          end

          public

          def load_all_rc(includes, excludes)
            rclist = {}
            loaded_rcs = []
            # determine default trees to scan
            cwd = Dir.getwd
            if Configurator::ROOT.size > cwd.size
              if Configurator::ROOT.start_with?(cwd)
                # Configurator::ROOT is part of cwd so include cwd only
                includes.unshift(cwd)
              else
                # Configurator::ROOT and cwd do not seem to be related so include both
                includes.unshift(Configurator::ROOT)
                includes.unshift(cwd)
              end
            else
              unless cwd.start_with?(Configurator::ROOT)
                # Configurator::ROOT and cwd do not seem to be related so include both
                includes.unshift(Configurator::ROOT)
                includes.unshift(cwd)
              else
                # cwd is part of Configurator::ROOT so include Configurator::ROOT only
                includes.unshift(Configurator::ROOT)
              end
            end
            BRIX11.log(2, "loading all configure rc files : includes = #{includes}, excludes = #{excludes}")
            begin
              # proceed with next dir to scan
              curdir = includes.shift
              BRIX11.log(5, "Examining [#{curdir}]")
              # check for rc file
              rcpath = File.join(curdir, 'etc', 'configurerc')
              # On Windows we can get lower and uppercase drive letters dependent
              # on how we are executed so we store the loaded rcs in lowercase
              if (!loaded_rcs.include?(rcpath.downcase)) && File.file?(rcpath)
                # load rc file
                rc_load(rclist, rcpath)
                loaded_rcs << rcpath.downcase
              end
              # get a list of paths to all subdirs
              dirlist = Dir[File.join(curdir, '*')].select {|p| File.directory?(p) }
              # filter out any excluded folders and prepend rest of subdirs to include list
              includes.unshift(*dirlist.select {|p| !excludes.include?(p) })
            end until includes.empty?
            rclist
          end

        end

        class Dependency

          class << self

            # DSL handler for dependencies block
            class DSLHandler
              def initialize(rc)
                @rc = rc
              end

              def require(featureid, &block)
                raise "Duplicate dependency defined for [#{featureid}]" if @rc.dependencies.has_key?(featureid.to_sym)
                dep = Dependency.new(:required, featureid.to_sym, &block)
                @rc.dependencies[dep.featureid] = dep
              end

              def optional(featureid, &block)
                raise "Duplicate dependency defined for [#{featureid}]" if @rc.dependencies.has_key?(featureid.to_sym)
                dep = Dependency.new(:optional, featureid.to_sym, &block)
                @rc.dependencies[dep.featureid] = dep
              end
            end # DSLHandler

            def load(rc, &block)
              DSLHandler.new(rc).instance_eval(&block)
            end

          end

          class Environment

            class << self

              # DSL handler for environment block
              class DSLHandler
                def initialize(env)
                  @env = env
                end

                def name(nm)
                  @env.name = nm
                end

                def description(desc)
                  @env.description = desc
                end

                def default(dflt)
                  @env.default = dflt
                end
              end # DSLHandler

              def load(env, &block)
                DSLHandler.new(env).instance_eval(&block)
              end

            end

            def initialize(varid, &block)
              @variable = varid
              @name = nil
              @description = nil
              @default = nil
              Environment.load(self, &block)
              validate
            end

            attr_reader :variable
            attr_accessor :name, :description, :default

            private
            def validate
              raise "Missing name for environment spec [#{@variable}]" unless @name
            end

          end # Environment

          # DSL handler for dependency specification block
          class DSLHandler
            def initialize(dep)
              @dep = dep
            end

            def environment(var, &block)
              raise "Duplicate environment spec for [#{var}]" if @dep.environment.has_key?(var.to_sym)
              env = Environment.new(var.to_sym, &block)
              @dep.environment[env.variable] = env
            end

            def requires(*var)
              @dep.requires.concat(var.flatten)
            end

            def file(*files)
              @dep.files.concat(files.flatten)
            end

            def exist(*paths)
              @dep.paths.concat(paths.flatten)
            end

            def executable(*paths)
              @dep.execs.concat(paths.flatten)
            end

            def evaluate(id, &block)
              @dep.evals << [id, block]
            end

            def library_path(*args)
              @dep.library_paths.concat(args.flatten.collect {|arg| arg.to_s })
            end
          end # DSLHandler


          def initialize(kind, featureid, &block)
            @kind = kind
            @featureid = featureid
            @environment = {}
            @requires = []
            @files = []
            @paths = []
            @execs = []
            @evals = []
            @library_paths = []
            @state = true # true until proven otherwise
            DSLHandler.new(self).instance_eval(&block)
          end

          attr_reader :kind, :featureid, :environment, :requires, :files, :paths, :execs, :evals, :library_paths
          attr_accessor :state

          def required?
            @kind == :required
          end

          def optional?
            @kind == :optional
          end

        end # Dependency

        class Feature

          class << self

            # DSL handler for features blocks
            class DSLHandler
              def initialize(rc)
                @rc = rc
              end

              def enable(featureid, &block)
                raise "Duplicate feature rule [#{featureid}]" if @rc.features.has_key?(featureid.to_sym)
                feature = Feature.new(true, featureid.to_sym)
                Feature::DSLHandler.new(feature).instance_eval(&block) if block_given?
                @rc.features[feature.featureid] = feature
              end

              def disable(featureid, &block)
                raise "Duplicate feature rule [#{featureid}]" if @rc.features.has_key?(featureid.to_sym)
                feature = Feature.new(false, featureid.to_sym)
                Feature::DSLHandler.new(feature).instance_eval(&block) if block_given?
                @rc.features[feature.featureid] = feature
              end
            end # DSLHandler

            def load(rc, &block)
              DSLHandler.new(rc).instance_eval(&block)
            end

          end

          # DSL handler for feature dependency blocks
          class DSLHandler
            def initialize(feature)
              @feature = feature
            end

            def depends_on(*args)
              @feature.prerequisites.concat(args.flatten.collect {|a| a.to_sym})
            end

            def depends_exclusively_on(arg)
              @feature.prerequisites << arg.to_sym
              @feature.exclusives << arg.to_sym
            end
          end # DSLHandler

          def initialize(state, featureid)
            @state = state
            @featureid = featureid
            @prerequisites = []
            @exclusives = []
          end

          attr_reader :state, :featureid, :prerequisites, :exclusives

        end # Feature

        # DSL handler for configure blocks
        class DSLHandler
          def initialize(rc)
            @rc = rc
          end

          def depends_on(*mod_id)
            @rc.prerequisites.concat(mod_id.flatten.collect {|mid| mid.to_sym})
          end

          def dependencies(&block)
            Dependency.load(@rc, &block)
          end

          def features(&block)
            Feature.load(@rc, &block)
          end

          # nested DSL handler for ridl/brix11/mpc include blocks
          class IncludeDSL
            def initialize(base, arr)
              @base = base
              @arr = arr
            end
            def include(*args)
              # add include paths; expand relative paths (not based on env var) based on @base
              @arr.concat(args.flatten.collect {|p| p.start_with?('$') ? p : File.expand_path(p, @base)})
            end
          end # IncludeDSL

          class RIDL_DSL < IncludeDSL
            def initialize(base, rc)
              super(base, rc.ridl_be_path)
              @rc = rc
            end

            class BackendDSL
              def initialize(hash)
                @hash = hash
              end
              def extends(*args)
                @hash[:bases].concat(args.flatten.collect {|arg| arg.to_sym })
              end
            end # BackendDSL

            def backend(arg, &block)
              @rc.ridl_backend[:backend] = arg.to_sym
              BackendDSL.new(@rc.ridl_backend).instance_eval(&block) if block_given?
            end
          end # RIDL_DSL

          class MPC_DSL < IncludeDSL
            def initialize(base, rc)
              super(base, rc.mpc_include)
              @rc = rc
            end
            def base(path)
              # expand specified path relative to rcfile folder
              @rc.mpc_base = File.expand_path(path.to_s, @base)
            end
            def mwc_include(*args)
              args.each do |arg|
                case arg
                when Hash
                  arg.each do |feature_id, includes|
                    @rc.mwc_include[feature_id.to_sym] ||= []
                    @rc.mwc_include[feature_id.to_sym].concat([includes].flatten)
                  end
                when Array
                  @rc.mwc_include[@rc.mod_id] ||= []
                  @rc.mwc_include[@rc.mod_id].concat(arg)
                else
                  @rc.mwc_include[@rc.mod_id] ||= []
                  @rc.mwc_include[@rc.mod_id] << arg
                end
              end
            end
          end # MPC_DSL

          def ridl(&block)
            RIDL_DSL.new(File.dirname(@rc.rcfile), @rc).instance_eval(&block)
          end

          def brix11(&block)
            IncludeDSL.new(File.dirname(@rc.rcfile), @rc.brix_path).instance_eval(&block)
          end

          def mpc(&block)
            MPC_DSL.new(File.dirname(@rc.rcfile), @rc).instance_eval(&block)
          end
        end # DSLHandler

        def initialize(mod_id, rcfile, &block)
          @mod_id = mod_id
          @rcfile = rcfile
          @prerequisites = []
          @dependencies = {}
          @features = {}
          @ridl_backend = {backend: nil, bases: []}
          @ridl_be_path = []
          @brix_path = []
          @mpc_base = nil
          @mpc_include = []
          @mwc_include = {}
          DSLHandler.new(self).instance_eval(&block)
        end

        attr_reader :mod_id,
                    :rcfile,
                    :prerequisites,
                    :dependencies,
                    :features,
                    :ridl_backend,
                    :ridl_be_path,
                    :brix_path,
                    :mpc_include,
                    :mwc_include

        attr_accessor :mpc_base

        def enabled?(allrc)
          # do all our own dependencies check out?
          if dependencies.values.all? {|dep| dep.optional? || dep.state }
            # are all our prerequisite modules available and enabled?
            return prerequisites.all? {|mod_id| allrc.has_key?(mod_id) && allrc[mod_id].enabled?(allrc) }
          end
          false
        end

        def disabled?(allrc)
          !enabled?(allrc)
        end

      end # RCSpec

    end

  end

end
