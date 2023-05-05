#--------------------------------------------------------------------
# @file    platform.rb
# @author  Martin Corino
#
# @brief  Configure tool platform detection
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'json'
require 'brix11/log'

module BRIX11
  module Common
    class Configure < Command::Base
      module Platform
        class << self
          include BRIX11::LogMethods

          private

          def get_os
            os = ENV['OS']
            os = `uname -s`.chomp if os.nil? || os.empty?
            os
          end

          public

          def platform_helpers
            @platform_helpers ||= Hash.new(->(_s, opts) {
                                              opts[:platform].merge!({
                                                os: :linux,
                                                bits: 0,
                                                defaults: {
                                                  libroot: '${SDKTARGETSYSROOT}/usr',
                                                  dll_dir: 'lib',
                                                  library_path_var: 'LD_LIBRARY_PATH',
                                                  test_configs: %w{LINUX Linux},
                                                  prj_type: BRIX11::Project.handler('gnumake').default_prj_type
                                                },
                                                project_type: lambda { |opts_, pt = nil, cc = nil|
                                                  opts_def = opts_[:platform][:defaults]
                                                  prjh = BRIX11::Project.handler(pt || opts_def[:prj_type], cc || opts_def[:prj_cc])
                                                  [prjh.class::ID, prjh.compiler]
                                                },
                                                config_prelude: %Q{
                                                    #define ACE_HAS_VERSIONED_NAMESPACE 1
                                                    #define ACE_MONITOR_FRAMEWORK 0
                                                  }.gsub(/^\s+/, ''),
                                                gnumake_prelude: %Q{
                                                    debug=0
                                                    inline=1
                                                    optimize=1
                                                  }.gsub(/^\s+/, '')
                                              })
                                            })
          end

          def platform_os
            @os ||= get_os
          end
        end

        platform_helpers[/windows/i] = ->(_s, opts) {
                                          opts[:platform].merge!({
                                            os: :windows,
                                            arch: ENV['PLATFORM'],
                                            bits: (ENV['PLATFORM'] == 'x64' ? 64 : 32),
                                            defaults: {
                                              dll_dir: 'bin',
                                              library_path_var: 'PATH',
                                              test_configs: %w{Win32},
                                              prj_type: 'vs2019'
                                            },
                                            project_type: lambda { |opts_, pt = nil, cc = nil|
                                              bits = opts_[:bitsize] || opts_[:platform][:bits]
                                              opts_def = opts_[:platform][:defaults]
                                              prjh = BRIX11::Project.handler(pt || opts_def[:prj_type], cc || opts_def[:prj_cc])
                                              comp = prjh.compiler.to_s.gsub(/x\d\d/, "x#{bits}")
                                              [prjh.class::ID, comp]
                                            },
                                            config_include: 'config-win32.h',
                                            config_prelude: %Q{
                                                #define ACE_HAS_VERSIONED_NAMESPACE 1
                                                #define ACE_MONITOR_FRAMEWORK 0
                                                #define __ACE_INLINE__ 1
                                                #define ACE_DISABLE_WIN32_INCREASE_PRIORITY
                                                #define ACE_DISABLE_WIN32_ERROR_WINDOWS
                                              }.gsub(/^\s+/, '')
                                          })
                                        }
        platform_helpers[/linux/i] = ->(_s, opts) {
                                        opts[:platform].merge!({
                                          os: :linux,
                                          arch: `uname -m`.chomp,
                                          defaults: {
                                            libroot: '/usr',
                                            dll_dir: 'lib',
                                            library_path_var: 'LD_LIBRARY_PATH',
                                            test_configs: %w{LINUX Linux},
                                            prj_type: BRIX11::Project.handler('gnumake').default_prj_type
                                          },
                                          project_type: lambda { |opts_, pt = nil, cc = nil|
                                            opts_def = opts_[:platform][:defaults]
                                            prjh = BRIX11::Project.handler(pt || opts_def[:prj_type], cc || opts_def[:prj_cc])
                                            [prjh.class::ID, prjh.compiler]
                                          },
                                          config_include: 'config-linux.h',
                                          config_prelude: %Q{
                                              #define ACE_HAS_VERSIONED_NAMESPACE 1
                                              #define ACE_MONITOR_FRAMEWORK 0
                                            }.gsub(/^\s+/, ''),
                                          gnumake_include: 'platform_linux.GNU',
                                          gnumake_prelude: %Q{
                                              debug=0
                                              inline=1
                                              optimize=1
                                            }.gsub(/^\s+/, '')
                                        })
                                        opts[:platform][:bits] = (opts[:platform][:arch] == 'x86_64' ? 64 : 32)
                                      }
        platform_helpers[/darwin/i] = ->(_s, opts) {
                                          opts[:platform].merge!({
                                            os: :darwin,
                                            arch: `uname -m`.chomp,
                                            defaults: {
                                              libroot: '/usr',
                                              dll_dir: 'lib',
                                              library_path_var: 'DYLD_LIBRARY_PATH',
                                              test_configs: %w{MACOSX},
                                              prj_type: BRIX11::Project.handler('gnumake').default_prj_type
                                            },
                                            project_type: lambda { |opts_, pt = nil, cc = nil|
                                              opts_def = opts_[:platform][:defaults]
                                              prjh = BRIX11::Project.handler(pt || opts_def[:prj_type], cc || opts_def[:prj_cc])
                                              [prjh.class::ID, prjh.compiler]
                                            },
                                            config_include: 'config-macosx.h',
                                            config_prelude: %Q{
                                                #define ACE_HAS_VERSIONED_NAMESPACE 1
                                                #define ACE_MONITOR_FRAMEWORK 0
                                              }.gsub(/^\s+/, ''),
                                            gnumake_include: 'platform_macosx.GNU',
                                            gnumake_prelude: %Q{
                                                debug=0
                                                inline=1
                                                optimize=1
                                              }.gsub(/^\s+/, '')
                                          })
                                          opts[:platform][:bits] = 64
                                        }

        def self.determin(opts)
          build_target = (opts[:target] || platform_os)
          _, ph = platform_helpers.detect { |re, _| re =~ build_target }
          opts[:platform] ||= {}
          (ph || platform_helpers.default).call(platform_os, opts)
          # see if there is a <build_target>.json to supplement/customize the defaults
          target_json = File.join(Exec.get_run_environment('X11_BASE_ROOT'), 'etc', build_target + '.json')
          if File.file?(target_json)
            begin
              tgt_spec = JSON.parse(IO.read(target_json))
            rescue JSON::ParserError => ex
              log_fatal("Error parsing JSON file #{target_json}: #{ex}")
            end
            opts[:platform][:os] = tgt_spec['os'].to_sym if tgt_spec.has_key?('os')
            opts[:platform][:bits] = tgt_spec['bits'] if tgt_spec.has_key?('bits')
            opts[:platform][:defaults][:libroot] = tgt_spec['libroot'] if tgt_spec.has_key?('libroot')
            opts[:platform][:defaults][:dll_dir] = tgt_spec['dll_dir'] if tgt_spec.has_key?('dll_dir')
            opts[:platform][:defaults][:library_path_var] = tgt_spec['library_path_var'] if tgt_spec.has_key?('library_path_var')
            opts[:platform][:defaults][:test_configs] = tgt_spec['test_configs'] if tgt_spec.has_key?('test_configs')
            opts[:platform][:defaults][:prj_type] = tgt_spec['project_type'] if tgt_spec.has_key?('project_type')
            opts[:platform][:defaults][:prj_cc] = tgt_spec['project_cc'] if tgt_spec.has_key?('project_cc')
            opts[:platform][:config_include] = tgt_spec['config_include'] if tgt_spec.has_key?('config_include')
            opts[:platform][:config_prelude] = (tgt_spec['config_prelude'].join("\n") << "\n") if tgt_spec.has_key?('config_prelude')
            opts[:platform][:config_post] = (tgt_spec['config_post'].join("\n") << "\n") if tgt_spec.has_key?('config_post')
            opts[:platform][:gnumake_include] = tgt_spec['gnumake_include'] if tgt_spec.has_key?('gnumake_include')
            opts[:platform][:gnumake_prelude] = (tgt_spec['gnumake_prelude'].join("\n") << "\n") if tgt_spec.has_key?('gnumake_prelude')
            opts[:platform][:gnumake_post] = (tgt_spec['gnumake_post'].join("\n") << "\n") if tgt_spec.has_key?('gnumake_post')
          end
          # always add target name in uppercase for non-standard target
          opts[:platform][:defaults][:test_configs] << build_target.upcase unless ph
          opts[:platform]
        end
      end # Platform
    end # Configure
  end # Common
end # BRIX11
