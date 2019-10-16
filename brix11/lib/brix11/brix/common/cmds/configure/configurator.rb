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

        def initialize(opts)
          @options = opts
          @features = {}
          @user_env = {}
          # determin platform
          Platform.determin(@options)
          # load all rc files
          @allrc = RCSpec.load_all_rc(@options[:includes].dup, @options[:excludes].dup)
          @rclist = {} # active modules
        end

        attr_reader :options, :features, :user_env, :rclist

        def dryrun?
          BRIX11.options.dryrun ? true : false
        end

        def process
          BRIX11.log(1, 'Processing specifications')
          # check all dependencies
          user_env_additions = {}
          @allrc.each do |mod_id, rc|
            BRIX11.show_msg("Processing dependencies for [#{mod_id}]")
            user_env_additions[mod_id] ||= {}
            rc.dependencies.each do |featureid, dep|
              dep_env_additions = {}
              # process environment specs
              dep.environment.each do |var, env|
                if @options[:variables].has_key?(var)
                  # use commandline specified variables
                  dep_env_additions[env.name] = @options[:variables][var]
                elsif Exec.get_run_environment(env.name).nil? && env.default
                  # try (platform) defaults (if any) if nothing has been specified
                  # any default path string will be expanded relative to the rcfile's location
                  val = @options[:platform][:defaults][env.default] || File.expand_path(env.default.to_s, File.dirname(rc.rcfile))
                  dep_env_additions[env.name] = val
                elsif (BRIX11.options.config.user_environment || {})[env.name]
                  # make sure to keep any dependency env var currently in the BRIX11 user env settings
                  dep_env_additions[env.name] = BRIX11.options.config.user_environment[env.name].gsub(/\$\{([^\s\/\}:;]+)\}/) { |m| ENV[$1] }
                end
              end
              # check if a commandline override has been specified
              if options[:features].has_key?(featureid)
                # set dependency state accordingly
                dep.state = options[:features][:featureid]
                if dep.required? && !dep.state
                  BRIX11.log_warning("Feature :#{featureid} has been disabled for module :#{rc.mod_id}. Disabling module.")
                end
              else
                # verify dependency files (expand env var references)
                dep.files.each do |fpath|
                  fnm = fpath.gsub(/\$\{([^\s\/\}:;]+)\}/) { |m| (dep_env_additions[$1] || Exec.get_run_environment($1)).to_s }
                  BRIX11.log(3, "Verifying [#{rc.mod_id}:#{featureid}] : file [#{fpath}] -> [#{fnm}]")
                  unless File.file?(fnm)
                    if dep.required?
                      BRIX11.log_warning("Verification of file [#{fpath}] failed for mandatory feature :#{featureid} for module :#{rc.mod_id}. Disabling module.")
                    else
                      BRIX11.log_information("Verification of file [#{fpath}] failed for feature :#{featureid} for module :#{rc.mod_id}. Disabling feature.")
                    end
                    dep.state = false
                    break # stop verifying
                  end
                end
                # verify dependency paths (expand env var references)
                dep.paths.each do |path|
                  fp = path.gsub(/\$\{([^\s\/\}:;]+)\}/) { |m| (dep_env_additions[$1] || Exec.get_run_environment($1)).to_s }
                  BRIX11.log(3, "Verifying [#{rc.mod_id}:#{featureid}] : exist [#{path}] -> [#{fp}]")
                  unless File.exist?(fp)
                    if dep.required?
                      BRIX11.log_warning("Verification of path [#{path}] failed for mandatory feature :#{featureid} for module :#{rc.mod_id}. Disabling module.")
                    else
                      BRIX11.log_information("Verification of path [#{path}] failed for feature :#{featureid} for module :#{rc.mod_id}. Disabling feature.")
                    end
                    dep.state = false
                    break # stop verifying
                  end
                end if dep.state # only verify paths if still needed
              end
              # keep environment additions if dependency fulfilled
              if dep.state
                user_env_additions[mod_id].merge!(dep_env_additions)
                dep_env_additions.each {|k,v| Exec.update_run_environment(k, v) }
              end
              # set the resulting feature state
              features[featureid] = StaticFeature.new(featureid, dep.state)
            end
          end
          # now filter active modules from full list
          @allrc.each do |mod_id, rc|
            # verify that this module *and* all of it's prerequisite modules
            # meet their requirements
            if rc.enabled?(@allrc)
              # update the user env additions
              @user_env.merge!(user_env_additions[mod_id] || {})
              # add all configured feature settings
              BRIX11.show_msg("Processing features for [#{mod_id}]")
              rc.features.each do |featureid, rcfeature|
                # chain (OR-ed) previous encountered feature specs
                other_feature = features[featureid]
                features[featureid] =  DerivedFeature.new(rcfeature, self, other_feature)
              end
              # add this module to active list
              @rclist[mod_id] = rc
            else
              # negate all configured feature settings
              rc.features.each do |featureid, rcfeature|
                # chain (OR-ed) previous encountered feature specs
                other_feature = features[featureid]
                # fix this feature to it's negated state
                features[featureid] =  DerivedFeature.new(StaticFeature.new(featureid, !rcfeature.state), self, other_feature)
              end
            end
          end
          # collect all unique library path additions of all active module dependencies
          lib_paths = @rclist.values.collect do |rc|
            rc.dependencies.values.select {|dep| dep.state }.collect do |dep|
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
          if rclist.has_key?(:acetao)
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
            # determin platform settings
            platform_opts = {}
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
