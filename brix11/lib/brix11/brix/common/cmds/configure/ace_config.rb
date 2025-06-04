#--------------------------------------------------------------------
# @file    ace_config.rb
# @author  Martin Corino
#
# @brief  Configure tool ACE config helper
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module BRIX11
  module Common
    class Configure < Command::Base
      module ACE_Config
        CONFIG_H = File.join('ace', 'config.h')

        PLATFORM_MACROS = File.join('include', 'makeinclude', 'platform_macros.GNU')

        DEFAULT_FEATURES = File.join('bin', 'MakeProjectCreator', 'config', 'default.features')

        OPENDDSCONFIG_H = File.join('dds', 'OpenDDSConfig.h')

        def self.config_include(opts)
          opts[:platform][:config_include] || "config-#{opts[:platform][:os]}.h"
        end

        def self.make_include(opts)
          opts[:platform][:gnumake_include] || "platform_#{opts[:platform][:os]}.GNU"
        end

        def self.default_platform_macros(opts)
          (opts[:platform][:gnumake_prelude] || '') + "buildbits=#{opts[:bitsize] || opts[:platform][:bits]}\n"
        end

        def self.create_config(cfg)
          # if no valid ACE_ROOT defined there is nothing we can do
          return unless Exec.get_run_environment('ACE_ROOT')
          # create the required config files
          platform_macros = make_include(cfg.options) ? File.join(Exec.get_run_environment('ACE_ROOT'), PLATFORM_MACROS) : nil
          config_h = File.join(Exec.get_run_environment('ACE_ROOT'), CONFIG_H)
          default_features = File.join(Exec.get_run_environment('ACE_ROOT'), DEFAULT_FEATURES)
          unless cfg.dryrun?
            # backup any existing files
            Util.backup_file(config_h)
            if make_include(cfg.options)
              Util.backup_file(platform_macros)
            end
            Util.backup_file(default_features)
          end
          # create new files
          BRIX11.show_msg("Creating #{config_h}")
          begin
            config_h_io = cfg.dryrun? ? STDOUT : File.new(config_h, 'w')
            config_h_io.puts("//----- #{CONFIG_H} -----") if cfg.dryrun?
            config_h_io << (cfg.options[:platform][:config_prelude] || '')
            config_h_io.puts(%Q{#include "ace/#{config_include(cfg.options)}"})
            config_h_io << (cfg.options[:platform][:config_post] || '')
          ensure
            config_h_io.close unless cfg.dryrun?
          end
          if platform_macros
            BRIX11.show_msg("Creating #{platform_macros}")
            begin
              platform_macros_io = cfg.dryrun? ? STDOUT : File.new(platform_macros, 'w')
              platform_macros_io.puts("#----- #{PLATFORM_MACROS} -----") if cfg.dryrun?
              # generate all feature macros
              cfg.features.each { |featureid, feature| platform_macros_io.puts("#{featureid}=#{feature.state ? '1' : '0'}") }
              # generate all cmdline specified macros (if any)
              if cfg.options[:defines]
                cfg.options[:defines].each { |m, v| platform_macros_io.puts("#{m}=#{v ? v : '1'}") }
              end
              # generate crossbuild defines
              if cfg.features.has_key?(:crossbuild) && cfg.features[:crossbuild].state
                platform_macros_io.puts("CROSS_COMPILE = #{cfg.user_env['CROSS_COMPILE']}")
                platform_macros_io.puts("ARCH :=")
                platform_macros_io.puts("FLAGS_C_CC += --sysroot=$(SDKTARGETSYSROOT)")
                platform_macros_io.puts("LDFLAGS += --sysroot=$(SDKTARGETSYSROOT)")
                # generate OpenDDS IDL path override if OpenDDS enabled
                if cfg.features.has_key?(:opendds) && cfg.features[:opendds].state
                  opendds_dir = File.basename(Exec.get_run_environment('DDS_ROOT'))
                  platform_macros_io.puts("override OPENDDS_IDL = $(X11_HOST_ROOT)/#{opendds_dir}/bin/opendds_idl")
                end
              end
              # generate default platform macros
              platform_macros_io << default_platform_macros(cfg.options)
              platform_macros_io.puts(%Q{include $(ACE_ROOT)/include/makeinclude/#{make_include(cfg.options)}})
              platform_macros_io << (cfg.options[:platform][:gnumake_post] || '')
            ensure
              platform_macros_io.close unless cfg.dryrun?
            end
          end
          if cfg.features.has_key?(:opendds) && cfg.features[:opendds].state
            # generate OpenDDS dds/OpenDDSConfig.h OpenDDS enabled
            opendds_folder = Exec.get_run_environment('DDS_ROOT')
            openddsconfig_h = File.join(opendds_folder, OPENDDSCONFIG_H)
            BRIX11.show_msg("Creating #{openddsconfig_h}")
            begin
              openddsconfig_h_io.puts("#----- #{OPENDDSCONFIG_H} -----") if cfg.dryrun?
              openddsconfig_h_io = cfg.dryrun? ? STDOUT : File.new(openddsconfig_h, 'w')
            ensure
              openddsconfig_h_io.close unless cfg.dryrun?
            end
          end
          BRIX11.show_msg("Creating #{default_features}")
          begin
            default_features_io = cfg.dryrun? ? STDOUT : File.new(default_features, 'w')
            default_features_io.puts("#----- #{DEFAULT_FEATURES} -----") if cfg.dryrun?
            # generate all feature definitions
            default_features_io.puts(cfg.options[:platform][:defaults][:features])
            cfg.features.each { |featureid, feature| default_features_io.puts("#{featureid}=#{feature.state ? '1' : '0'}") }
          ensure
            default_features_io.close unless cfg.dryrun?
          end
        end
      end
    end
  end
end
