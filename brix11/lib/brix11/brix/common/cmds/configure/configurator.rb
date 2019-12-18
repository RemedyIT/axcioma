#--------------------------------------------------------------------
# @file    configurator.rb
# @author  Martin Corino
#
# @brief   Configure tool configurator
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module BRIX11

  module Common

    class Configure  < Command::Base

      class Configurator

        ROOT = File.dirname(BRIX11_BASE_ROOT)

        class DerivedFeature
          def initialize(rcfeature, cfg, other_feature = nil)
            @rcfeature = rcfeature
            @cfg = cfg
            @other_feature = other_feature
          end

          def featureid
            @rcfeature.featureid
          end

          def state
            other_state = @other_feature ? @other_feature.state : false
            if @rcfeature.prerequisites.empty?
              other_state || @rcfeature.state
            else
              other_state || (@rcfeature.prerequisites.any? {|freq| @cfg.features[freq] ? @cfg.features[freq].state : false } ? @rcfeature.state : !@rcfeature.state)
            end
          end

          def exclusives
            @rcfeature.exclusives + (@other_feature ? @other_feature.exclusives : [])
          end
        end # DerivedFeature

        class StaticFeature
          def initialize(featureid, state)
            @featureid = featureid
            @state = state
          end
          attr_reader :featureid, :state
          def prerequisites
            []
          end
          def exclusives
            []
          end
        end # StaticFeature

        class CfgModule

          class CfgDependency

            Evaluator = Class.new do
              def initialize(rcdep)
                @rcdep = rcdep
              end
              def getenv(varname)
                @rcdep.get_var(varname)
              end
            end

            def initialize(mod, rcdep)
              @mod = mod
              @rcdep = rcdep
              @env_additions = {}
            end

            def get_var(varname)
              (@env_additions[varname] || Exec.get_run_environment(varname)).to_s
            end

            def expand_var(val)
              val.gsub(/\$\{([^\s\/\}:;]+)\}/) { |m| get_var($1) }
            end
            private :expand_var

            def featureid
              @rcdep.featureid
            end

            def state
              @rcdep.state
            end

            def options
              @mod.options
            end

            def library_paths
              @rcdep.library_paths
            end

            def process
              # process environment specs
              @rcdep.environment.each do |var, env|
                if options[:variables].has_key?(var)
                  # use commandline specified variables
                  val = expand_var(options[:variables][var])
                  # any relative path string will be expanded relative to the cwd
                  val = File.expand_path(val) if val.start_with?('./', '../')
                  @env_additions[env.name] = val
                elsif env.default
                  # match (platform) defaults (if any) to any specified default
                  val = options[:platform][:defaults][env.default]
                  # otherwise just use specified default value
                  val ||= env.default.to_s
                  # expand any reffed vars
                  val = expand_var(val)
                  # any default relative path string will be expanded relative to the rcfile's location
                  val = File.expand_path(val, File.dirname(@mod.rcfile)) if val.start_with?('./', '../')
                  # store result
                  @env_additions[env.name] = val
                end
              end
              # check if a commandline override has been specified
              if options[:features].has_key?(featureid)
                # set dependency state accordingly
                @rcdep.state = options[:features][:featureid]
                if @rcdep.required? && !@rcdep.state
                  BRIX11.log_warning("Feature :#{featureid} has been disabled for module :#{@mod.mod_id}. Disabling module.")
                end
              else
                # verify required dependency variables
                @rcdep.requires.each do |var|
                  BRIX11.log(3, "Verifying [#{@mod.mod_id}:#{featureid}] : requires :#{var}")
                  unless options[:variables].has_key?(var)
                    if @rcdep.required?
                      BRIX11.log_warning("Verification of require [:#{var}] failed for mandatory feature :#{featureid} for module :#{@mod.mod_id}. Disabling module.")
                    else
                      BRIX11.log_information("Verification of require [:#{var}] failed for feature :#{featureid} for module :#{@mod.mod_id}. Disabling feature.")
                    end
                    @rcdep.state = false
                    break # stop verifying
                  end
                end
                # verify dependency files (expand env var references)
                @rcdep.files.each do |fpath|
                  fnm = expand_var(fpath)
                  BRIX11.log(3, "Verifying [#{@mod.mod_id}:#{featureid}] : file [#{fpath}] -> [#{fnm}]")
                  unless File.file?(fnm)
                    if @rcdep.required?
                      BRIX11.log_warning("Verification of file [#{fpath}] failed for mandatory feature :#{featureid} for module :#{@mod.mod_id}. Disabling module.")
                    else
                      BRIX11.log_information("Verification of file [#{fpath}] failed for feature :#{featureid} for module :#{@mod.mod_id}. Disabling feature.")
                    end
                    @rcdep.state = false
                    break # stop verifying
                  end
                end if @rcdep.state # only verify files if still needed
                # verify dependency paths (expand env var references)
                @rcdep.paths.each do |path|
                  fp = expand_var(path)
                  BRIX11.log(3, "Verifying [#{@mod.mod_id}:#{featureid}] : exist [#{path}] -> [#{fp}]")
                  unless File.exist?(fp)
                    if @rcdep.required?
                      BRIX11.log_warning("Verification of path [#{path}] failed for mandatory feature :#{featureid} for module :#{@mod.mod_id}. Disabling module.")
                    else
                      BRIX11.log_information("Verification of path [#{path}] failed for feature :#{featureid} for module :#{@mod.mod_id}. Disabling feature.")
                    end
                    @rcdep.state = false
                    break # stop verifying
                  end
                end if @rcdep.state # only verify paths if still needed
                # check if a custom PATH addition (prepend) is defined
                if options[:variables][:path]
                  conf_path = "#{options[:variables][:path]}#{File::PATH_SEPARATOR}#{ENV['PATH']}"
                else
                  conf_path = ENV['PATH']
                end
                # verify dependency executables (expand env var references)
                @rcdep.execs.each do |name|
                  exe = expand_var(name)
                  BRIX11.log(3, "Verifying [#{@mod.mod_id}:#{featureid}] : exec [#{name}] -> [#{exe}]")
                  unless conf_path.split(File::PATH_SEPARATOR).any? { |sp| File.executable?(File.join(sp, exe)) }
                    if @rcdep.required?
                      BRIX11.log_warning("Verification of executable [#{name}] failed for mandatory feature :#{featureid} for module :#{@mod.mod_id}. Disabling module.")
                    else
                      BRIX11.log_information("Verification of executable [#{name}] failed for feature :#{featureid} for module :#{@mod.mod_id}. Disabling feature.")
                    end
                    @rcdep.state = false
                    break # stop verifying
                  end
                end if @rcdep.state # only verify execs if still needed
                # verify evaluation blocks
                @rcdep.evals.each do |id, block|
                  BRIX11.log(3, "Verifying [#{@mod.mod_id}:#{featureid}] : evaluate [#{id}, #{block.inspect}]")
                  unless Evaluator.new(self).instance_eval(&block)
                    if @rcdep.required?
                      BRIX11.log_warning("Verification of evaluate [#{id}] failed for mandatory feature :#{featureid} for module :#{@mod.mod_id}. Disabling module.")
                    else
                      BRIX11.log_information("Verification of evaluate [#{id}] failed for feature :#{featureid} for module :#{@mod.mod_id}. Disabling feature.")
                    end
                    @rcdep.state = false
                    break # stop verifying
                  end
                end if @rcdep.state # only verify evals if still needed
              end
              # keep environment additions if dependency fulfilled
              if @rcdep.state
                # keep in current runtime env
                @env_additions.each {|k,v| Exec.update_run_environment(k, v) }
                # keep for user env additions
                @mod.env_additions.merge!(@env_additions)
              end
            end
          end

          def initialize(cfg, rcspec)
            @cfg = cfg
            @rcspec = rcspec
            @deplist = []
            @env_additions = {}
          end

          attr_reader :env_additions

          def mod_id
            @rcspec.mod_id
          end

          def rcfile
            @rcspec.rcfile
          end

          def features
            @rcspec.features
          end

          def options
            @cfg.options
          end

          def dependencies
            @deplist
          end

          def ridl_backend
            @rcspec.ridl_backend
          end

          def ridl_be_path
            @rcspec.ridl_be_path
          end

          def brix_path
            @rcspec.brix_path
          end

          def mpc_include
            @rcspec.mpc_include
          end

          def mwc_include
            @rcspec.mwc_include
          end

          def mpc_base
            @rcspec.mpc_base
          end

          def process
            # return if we're already processed
            return if @cfg.allmod.has_key?(mod_id)
            # add us to the processed list
            @cfg.allmod[mod_id] = self
            # make sure all prerequisites are evaluated first
            @rcspec.prerequisites.each do |modid|
              CfgModule.new(@cfg, @cfg.allrc[modid]).process if @cfg.allrc.has_key?(modid) && (!@cfg.allmod.has_key?(modid))
            end
            # evaluate our dependency specs
            BRIX11.show_msg("Processing dependencies for [#{mod_id}]")
            @rcspec.dependencies.each do |featureid, rcdep|
              dep =  CfgDependency.new(self, rcdep)
              dep.process
              @deplist << dep
              # set the resulting feature state
              @cfg.features[featureid] = StaticFeature.new(featureid, dep.state)
            end
          end

          def enabled?
            @rcspec.enabled?(@cfg.allrc)
          end
        end

        def initialize(opts)
          @options = opts
          @features = {}
          @user_env = {}
          # determine platform
          Platform.determin(@options)
          # load all rc files
          @allrc = RCSpec.load_all_rc(@options[:includes].dup, @options[:excludes].dup)
          @allmod = {}
          @cfglist = {} # active modules
        end

        attr_reader :options, :features, :user_env, :allrc, :allmod, :cfglist

        def dryrun?
          BRIX11.options.dryrun ? true : false
        end

        def process
          BRIX11.log(1, 'Processing specifications')
          # reset user defined runtime environment but keep X11_BASE_ROOT
          base_root = Exec.get_run_environment('X11_BASE_ROOT')
          Exec.reset_run_environment
          Exec.update_run_environment('X11_BASE_ROOT', base_root) if base_root
          # process all loaded specs
          @allrc.each do |mod_id, rcspec|
            BRIX11.log(3, "Checking specifications for [#{mod_id}]")
            CfgModule.new(self, rcspec).process
          end
          # now filter active modules from full list
          @allmod.each do |mod_id, mod|
            # verify that this module *and* all of it's prerequisite modules
            # meet their requirements
            if mod.enabled?
              # update the user env additions
              @user_env.merge!(mod.env_additions)
              # add all configured feature settings
              BRIX11.show_msg("Processing features for [#{mod_id}]")
              mod.features.each do |featureid, rcfeature|
                # chain (OR-ed) previous encountered feature specs
                other_feature = features[featureid]
                features[featureid] =  DerivedFeature.new(rcfeature, self, other_feature)
              end
              # add this module to active list
              @cfglist[mod_id] = mod
            else
              # negate all configured feature settings
              mod.features.each do |featureid, rcfeature|
                # chain (OR-ed) previous encountered feature specs
                other_feature = features[featureid]
                # fix this feature to it's negated state
                features[featureid] =  DerivedFeature.new(StaticFeature.new(featureid, !rcfeature.state), self, other_feature)
              end
            end
          end
          # collect all unique library path additions of all active module dependencies
          lib_paths = @cfglist.values.collect do |mod|
            mod.dependencies.select {|dep| dep.state }.collect do |dep|
              dep.library_paths.collect do |str|
                # expand any env var references in string
                path = str.gsub(/\$\{([^\s\/\}:;]+)\}/) { |m| Exec.get_run_environment($1).to_s }
                # expand any special vars (currently only '${:DDL_DIR}')
                path.gsub(/\$\{:DLL_DIR\}/) {|m| options[:platform][:defaults][:dll_dir] }
              end
            end
          end.flatten.uniq
          # add library path additions to platform specific env var in user env settings
          libpath_var = options[:platform][:defaults][:library_path_var]
          lib_paths << "${#{libpath_var}}"
          @user_env[libpath_var] = lib_paths.join(File::PATH_SEPARATOR)
          # add any custom PATH addition
          if options[:variables][:path]
            if @user_env.has_key?('PATH') # in case libpath_var == PATH
              @user_env['PATH'] = "#{options[:variables][:path]}#{File::PATH_SEPARATOR}#{@user_env['PATH']}"
            else
              @user_env['PATH'] = "#{options[:variables][:path]}#{File::PATH_SEPARATOR}${PATH}"
            end
          end
          # override all commandline specified features
          options[:features].each do |featureid, state|
            # simple override, no chaining
            features[featureid] = StaticFeature.new(featureid, state)
          end
          # check any exclusive feature dependencies
          features.each do |featureid, feature|
            if feature.exclusives.count {|excl_fid| features.has_key?(excl_fid) && features[excl_fid].state } > 1
              BRIX11.log_fatal("Feature :#{featureid} allows only one of it's prerequisite features [:#{feature.exclusives.join(', :')}] to be enabled.")
            end
          end
        end

        def generate
          BRIX11.log(1, 'Generating configuration')
          # only create ACE & TAO configuration if that module is included
          if cfglist.has_key?(:acetao)
            # create ACE & TAO configuration
            ACE_Config.create_config(self)
          end
          # generate RIDL config
          RIDL_Config.create_config(self)
          # generate BRIX11 config
          BRIX11_Config.create_config(self)
          # generate MPC config
          MPC_Config.create_config(self)
          # generate MWC project config
          MPC_Config.create_workspace(self)
          # setup HOST environment
          if features.has_key?(:crossbuild) && features[:crossbuild].state && !options[:variables].has_key?(:x11_host_root)
            # when no X11 host root is specified for a crossbuild we set up a minimal host environment ourselves
            HostSetup.create_host_environment(self)
          end
        end

        class << self
          private

          def print_file(fnm, title)
            pfx_len = ((58 - title.size) / 2)
            STDOUT.print('=' * pfx_len)
            STDOUT.puts(" #{title} #{'=' * (58 - (pfx_len + title.size))}")
            STDOUT.puts(File.read(fnm))
          end

          def get_test_config_from(features_cfg_file)
            # determine platform settings
            platform_opts = {}
            platform_opts[:target] = BRIX11.options.config.target_platform
            Platform.determin(platform_opts)
            # determin test configurations
            test_configs = []
            test_configs.concat(platform_opts[:platform][:defaults][:test_configs] || []) # platform defaults
            test_configs << 'FIXED_BUGS_ONLY' # default for now
            features = File.readlines(features_cfg_file).collect do |ln|
              feature = nil
              if /\A\s*\w+\s*=\s*(0|1)\s*\Z/ =~ ln
                feature, val = ln.split('=').collect {|s| s.strip }
                feature = nil if val.to_i == 0
              end
              feature
            end.compact
            # upcase each active feature to provide it's test config
            test_configs.concat(features.collect {|ftr| ftr.upcase })
          end
        end

        def self.print_config(workspace)
          # printing the configuration requires an existing ACE_ROOT and config files
          if Exec.get_run_environment('ACE_ROOT') && File.exist?(File.join(Exec.get_run_environment('ACE_ROOT'),'ace', 'config.h'))
            _test_configs = nil
            _ace_root = Exec.get_run_environment('ACE_ROOT')
            print_file(File.join(_ace_root, 'ace', 'config.h'), 'config.h')
            _cfg_file = File.join(_ace_root, 'include', 'makeinclude', 'platform_macros.GNU')
            print_file(_cfg_file, 'platform_macros.GNU') if File.exist?(_cfg_file)
            _cfg_file = File.join(_ace_root, 'bin', 'MakeProjectCreator', 'config', 'default.features')
            if File.exist?(_cfg_file)
              print_file(_cfg_file, 'default.features')
              _test_configs = get_test_config_from(_cfg_file)
            end
            if Exec.get_run_environment('TAOX11_ROOT')
              _cfg_file = File.join(Exec.get_run_environment('TAOX11_ROOT'), 'bin', 'MPC', 'config', 'MPC.cfg')
              print_file(_cfg_file, 'MPC.cfg') if File.exist?(_cfg_file)
            end
            _cfg_file = File.join(Configurator::ROOT, '.ridlrc')
            print_file(_cfg_file, '.ridlrc') if File.exist?(_cfg_file)
            _cfg_file = File.join(Configurator::ROOT, '.brix11rc')
            print_file(_cfg_file, '.brix11rc') if File.exist?(_cfg_file)
            _cfg_file = File.join(Configurator::ROOT, (workspace || 'workspace')+'.mwc')
            print_file(_cfg_file, (workspace || 'workspace')+'.mwc') if File.exist?(_cfg_file)
            STDOUT.puts('=' * 60)
            STDOUT.puts("Test config: #{_test_configs.join(' ')}") if _test_configs
            STDOUT.puts
          else
            BRIX11.log_fatal("Cannot find an existing configuration.")
          end
        end

        def self.get_test_config
          _ace_root = Exec.get_run_environment('ACE_ROOT')
          _cfg_file = File.join(_ace_root, 'bin', 'MakeProjectCreator', 'config', 'default.features')
          File.exist?(_cfg_file) ? get_test_config_from(_cfg_file) : []
        end

      end # Configurator

    end # Configure

  end # Common

end # BRIX11
