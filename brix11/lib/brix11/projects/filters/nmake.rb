#--------------------------------------------------------------------
# @file    nmake.rb
# @author  Martin Corino
#
# @brief   NMAKE filter for brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module BRIX11
  module Project
      module Filter
        class Makefile
          include Formatter::Filter::FilterMethods

          TOOL_PATTERNS = [
            /Project:\s+(?<name>Makefile.*)\Z/,
            /.*nmake\.exe.*\/f\s+(?<desc>Makefile.*)\Z/
          ]
          OUTPUT_PATTERNS = [
            [:warning,     /(?<name>.*)\s+(?<desc>will not be built due to the following missing library: .*)/]
          ]

          def initialize(verbosity)
            @action = 'Making'
            @pattern, @traverse_pattern = TOOL_PATTERNS
            @verbosity = verbosity
            @tool_verbosity = 1
          end

          # override
          def match(s)
            if rem = tool_pattern.match(s)
              report_tool(rem)
              return true
            elsif rem = @traverse_pattern.match(s)
              if verbosity > tool_verbosity
                output.println(bold('-> '), rem[:desc])
              end
              return true
            end
            false
          end

          # override
          def output_patterns
            OUTPUT_PATTERNS
          end
        end # Makefile

        class NMake
          include Formatter::Filter::FilterMethods

          OUTPUT_PATTERNS = [
            [:ignore,     /Microsoft \(R\) Program Maintenance Utility.*/],
            [:ignore,     /Copyright \(C\) Microsoft Corporation.*/],
            [:ignore,     /tempfile.*\.bat\Z/],
            [:ignore,     /if not exist.*/],
            [:error,      /NMAKE\s+:\s+[Ff]atal [Ee]rror U1077:\s.*\s:\s+(?<desc>return code.*)\Z/],
            [:error,      /NMAKE\s+:\s+[Ff]atal [Ee]rror U\d+:\s.*\s:\s+(?<desc>return code.*)\Z/],
            [:error,      /LINK\s+:\s+[Ff]atal [Ee]rror\s+LNK\d+:\s+(?<desc>.*)\Z/],
            [:warning,    /NMAKE\s+:\s+[Ww]arning\s+U\d+:\s+(?<desc>.*)\Z/],
          ]

          def initialize(verbosity)
            @action = 'Make'
            @tool = 'nmake'
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
        end # NMake
      end # Filter
  end # Project
end # BRIX11
