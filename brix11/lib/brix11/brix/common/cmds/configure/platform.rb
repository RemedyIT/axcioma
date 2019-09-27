#--------------------------------------------------------------------
# @file    platform.rb
# @author  Martin Corino
#
# @brief  Configure tool platform detection
#
# @copyright Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
#--------------------------------------------------------------------

module BRIX11

  module Common

    class Configure  < Command::Base

      module Platform

        class << self
          private

          def get_os
            os = ENV['OS']
            os = `uname -s`.chomp if os.nil? || os.empty?
            os
          end

          public

          def platform_helpers
            @platform_helpers ||= Hash.new(->(s, opts) { opts[:platform][:os] = s.downcase.to_sym })
          end

          def platform_os
            @os ||= get_os
          end
        end

        platform_helpers[/windows/i] = ->(s, opts) {
                                          opts[:platform][:os] = :windows
                                          opts[:platform][:arch] = ENV['PLATFORM']
                                          opts[:platform][:bits] = (opts[:platform][:arch] == 'x64' ? 64 : 32)
                                          opts[:platform][:defaults] = {
                                            :dll_dir => 'bin',
                                            :library_path_var => 'PATH',
                                            :test_configs => %w{Win32}
                                          }
                                          opts[:platform][:project_type] = ->(bits, pt=nil, cc=nil) {
                                            prjh = BRIX11::Project.handler(pt || 'vs2017', cc)
                                            comp = prjh.compiler.to_s.gsub(/x\d\d/, "x#{bits}")
                                            [prjh.class::ID, comp]
                                          }
                                        }
        platform_helpers[/linux/i] = ->(s, opts) {
                                        opts[:platform][:os] = :linux
                                        opts[:platform][:arch] = `uname -m`.chomp
                                        opts[:platform][:bits] = (opts[:platform][:arch] == 'x86_64' ? 64 : 32)
                                        opts[:platform][:defaults] = {
                                          :libroot => '/usr',
                                          :incpath => '/usr/include',
                                          :libpath => (opts[:platform][:bits] == 64 ? '/usr/lib64' : '/usr/lib'),
                                          :dll_dir => 'lib',
                                          :library_path_var => 'LD_LIBRARY_PATH',
                                          :test_configs => %w{LINUX Linux}
                                        }
                                        opts[:platform][:project_type] = ->(bits, pt=nil, cc=nil) {
                                          prjh = BRIX11::Project.handler(pt || 'gnuautobuild', cc)
                                          [prjh.class::ID, prjh.compiler]
                                        }
                                      }

        def self.determin(opts)
          _, ph = platform_helpers.detect {|re, _| re =~ platform_os }
          ph ||= platform_helpers.default
          opts[:platform] ||= {}
          ph.call(platform_os, opts)
        end
      end

    end

  end

end
