#--------------------------------------------------------------------
# @file    doxygen.rb
# @author  Martin Corino
#
# @brief   BRIX11 Doxygen document generator
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'fileutils'

module BRIX11

  module Common

    class GenerateDocumentation < Command::Base

      module Doxygen

        class NullFilter
          def print(_); end
          def flush; end
        end

        class << self

          private

          def resolve_path_var(v)
            Exec.get_run_environment(v) || v
          end

          def has_doxygen?
            !!(Sys.expand('doxygen -v') =~ /\d+\.\d+\.\d+/)
          end

          public

          def generate(config, noredirect)
            BRIX11.show_msg('Generating source documentation')

            # resolve possible env vars in config path
            config = config.gsub(/\$\{(\w+)\}/) { |_| resolve_path_var($1) }
            # check for availability of doxygen
            if has_doxygen?
              Sys.in_dir(Exec.get_run_environment('X11_BASE_ROOT')) do
                args = []
                args << '-q' unless noredirect
                args << config
                Exec.runcmd('doxygen', *args, noredirect ? {} : {silent: true, filter: NullFilter.new})
              end
            else
              BRIX11.log_warning('No source documentation will be generated as the doxygen tool is not available!')
            end
          end
        end

        def self.run(opts)
          generate(opts[:doxygen_config], (!!opts[:noredirect]) || BRIX11.verbose?) if opts[:doxygen_config]
        end

      end # Doxygen

    end # GenerateDocumentation

  end # Common

end # BRIX11
