#--------------------------------------------------------------------
# @file    gnumake.rb
# @author  Martin Corino
#
# @brief   GNU make filter for brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module BRIX11
  module Project
      module Filter
        class GNUMakefile

          include Formatter::Filter::FilterMethods

          TOOL_PATTERNS = [
              /GNUmakefile: (?<name>.*)/,
              /.*make.*\[\d+\]: (?<desc>(Leaving|Entering) directory .*)/
          ]
          OUTPUT_PATTERNS = [
            [:warning,     /(?<name>.*)\s+(?<desc>will not be built due to the following missing library: .*)/]
          ]

          def initialize(verbosity)
            @action = 'Making'
            @pattern, @traverse_pattern = TOOL_PATTERNS
            @verbosity = verbosity
          end

          # override
          def match(s)
            if rem = tool_pattern.match(s)
              report_tool(rem)
              return true
            elsif rem = @traverse_pattern.match(s)
              if verbosity > tool_verbosity
                output.println(bold(/Entering/ =~ rem[:desc] ? '-> ' : '<- '), rem[:desc])
              end
              return true
            end
            false
          end

          # override
          def output_patterns
            OUTPUT_PATTERNS
          end

        end # GNUMakefile

        class GMake

          include Formatter::Filter::FilterMethods

          OUTPUT_PATTERNS = [
            [:info,       /.*make.*:.*Error.*\(ignored\)/],
            [:error,      /(?<name>.*):(?<line>\d*): (?<desc>\*\*\* .*)/],
            [:error,      /.*make.*: \*\*\* (?<desc>.*)/],
            [:error,      /.*make.*: (?<desc>Target (.*) not remade because of errors.)/],
            [:error,      /.*[Cc]ommand not found.*/],
            [:error,      /^\s*Error:\s*(?<desc>.*)/],
            [:warning,    /(?<name>.*[Mm]akefile):(?<line>\d*): warning: (?<desc>.*)/],
            [:warning,    /.*make.*\[.*\] Error (?<desc>[-]{0,1}\d*.*)/],
            [:warning,    /(?<name>.*):(?<line>\d*): (?<desc>\S*: No such file or directory)/],
            [:warning,    /.*make.*: (?<desc>Circular .* dependency dropped.)/],
            [:warning,    /Warning:\s*(?<desc>.*)/]
          ]

          def initialize(verbosity)
            @action = 'Make'
            @tool = 'make'
            @tool_verbosity = 2
            @verbosity = verbosity
          end

          def match(s)
            @last_output_category = nil
            filter_output(s)
          end

          # override
          def output_patterns
            OUTPUT_PATTERNS
          end

        end # GMake
      end # Filter
  end # Project
end # BRIX11
