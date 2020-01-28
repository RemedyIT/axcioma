#--------------------------------------------------------------------
# @file    hostsetup.rb
# @author  Martin Corino
#
# @brief   Configure tool cross build host setup
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------


require 'fileutils'

module BRIX11

  module Common

    class Configure  < Command::Base

      module HostSetup

        FOLDER = 'HOST'

        MWC = 'host'

        SOURCE_CONFIG = {
            'ACE' => {
              'ace' => :norecurse,
              'ace/os_include' => :recurse,
              'bin' => :norecurse,
              'bin/MakeProjectCreator' => :recurse,
              'bin/PerlACE' => :recurse,
              'apps/gperf/src' => :recurse,
              'include' => :recurse
            },
            'TAO' => {
              '.' => :norecurse,
              'TAO_IDL' => :recurse,
              'MPC' => :recurse,
              'tao' => :norecurse
            }
        }

        NO_HIDDEN = /^\..*/ # everything starting with '.'

        EXCLUDES = [
            'ace/config.h',
            'bin/MakeProjectCreator/config/default.features',
            'include/makeinclude/platform_macros.GNU',
            /.*\.so.*/,
        ]

        class << self
            private
            def in_dir(dir)
                curcwd_ = Dir.getwd
                begin
                    Dir.chdir(dir)
                    yield if block_given?
                ensure
                    Dir.chdir(curcwd_)
                end
            end

            def setup_folder(dst, dir, recurse)
                FileUtils.mkdir_p(File.join(dst, dir))
                Dir.glob(File.join(dir, '*')).each do |p|
                    unless File.basename(p).start_with?('.')
                        if !File.directory?(p)
                            unless EXCLUDES.any? {|pat| pat.is_a?(String) ? (pat == p) : (pat =~ p) }
                                File.link(p, File.join(dst, p))
                            end
                        elsif recurse
                            setup_folder(dst, p, recurse)
                        end
                    end
                end
            end

            def setup(src, dst, mod)
                dst = File.join(File.expand_path(dst), mod)
                FileUtils.mkdir_p(dst)
                in_dir(src) do
                    HostSetup::SOURCE_CONFIG[mod].each do |dir, opt|
                        setup_folder(dst, dir, opt == :recurse)
                    end
                end
            end

            def create_build_config(x11_host_root, cfg)
              ace_config = File.join(x11_host_root, 'ACE', ACE_Config::CONFIG_H)
              platform_macros = File.join(x11_host_root, 'ACE', ACE_Config::PLATFORM_MACROS)
              default_features = File.join(x11_host_root, 'ACE', ACE_Config::DEFAULT_FEATURES)
              begin
                config_h_io = cfg.dryrun? ? STDOUT : File.new(ace_config, 'w')
                config_h_io.puts("//----- HOST #{ACE_Config::CONFIG_H} -----") if cfg.dryrun?
                config_h_io << "#define ACE_MONITOR_FRAMEWORK 0\n"
                config_h_io.puts('#include "ace/config-linux.h"')
              ensure
                config_h_io.close unless cfg.dryrun?
              end

              begin
                platform_macros_io = cfg.dryrun? ? STDOUT : File.new(platform_macros, 'w')
                platform_macros_io.puts("#----- HOST #{ACE_Config::PLATFORM_MACROS} -----") if cfg.dryrun?
                # generate default platform macros
                platform_macros_io << %Q{
                  debug=0
                  c++11=1
                  no_deprecated=0
                  inline=1
                  optimize=1
                }.gsub(/^\s+/, '')
                platform_macros_io.puts('include $(ACE_ROOT)/include/makeinclude/platform_linux.GNU')
              ensure
                platform_macros_io.close unless cfg.dryrun?
              end

              begin
                default_features_io = cfg.dryrun? ? STDOUT : File.new(default_features, 'w')
                default_features_io.puts("#----- HOST #{ACE_Config::DEFAULT_FEATURES} -----") if cfg.dryrun?
                default_features_io << %Q{
                  bzip2=0
                  zlib=0
                  stl=1
                  xerces3=0
                  ssl=0
                }.gsub(/^\s+/, '')
              ensure
                default_features_io.close unless cfg.dryrun?
              end
            end

            def create_mwc_config(x11_host_root, cfg)
              mwc_config = File.join(x11_host_root, "#{MWC}.mwc")
              begin
                mwc_config_io = cfg.dryrun? ? STDOUT : File.new(mwc_config, 'w')
                mwc_config_io.puts("#----- HOST MWC config -----") if cfg.dryrun?
                mwc_config_io << %Q{
                  workspace {
                   ACE/ace
                   ACE/apps/gperf/src
                   TAO/TAO_IDL
                  }
                }.gsub(/^\s+/, '')
              ensure
                mwc_config_io.close unless cfg.dryrun?
              end
            end
        end

        def self.create_host_environment(cfg)
          # only setup if no $X11_BASE_ROOT/HOST folder exists yet
          x11_host_root = File.join(Exec.get_run_environment('X11_BASE_ROOT'), FOLDER)
          if File.directory?(x11_host_root)
            BRIX11.log_information('$X11_BASE_ROOT/HOST already exists. Assuming existing crossbuild host environment to be used.')
          else
            BRIX11.show_msg("Setting up crossbuild host environment at $X11_BASE_ROOT/#{FOLDER}")
            x11_host_acetao_root = File.join(x11_host_root, 'ACE')
            # link necessary source code
            setup(Exec.get_run_environment('ACE_ROOT'), x11_host_acetao_root, 'ACE') unless cfg.dryrun?
            setup(Exec.get_run_environment('TAO_ROOT'), x11_host_acetao_root, 'TAO') unless cfg.dryrun?
            # create build configuration
            create_build_config(x11_host_acetao_root, cfg)
            # create MWC config
            create_mwc_config(x11_host_acetao_root, cfg)
          end
        end
      end

    end

  end

end
