#--------------------------------------------------------------------
# @file    ridl.rb
# @author  Martin Corino
#
# @brief   RIDL compiler filter for brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module BRIX11

  module Project

    module Filter

      class RIDLCompiler
        include Formatter::Filter::FilterMethods

        TOOL_PATTERN = /(?<tool>ridlc)\s.*\s(?<name>\S+\.(p|P)?(idl|IDL))\Z/
        OUTPUT_PATTERNS = [
            [:error, /IDL::ParseError:\s+(?<desc>.*)/]
        ]
        NEXT_PATTERN = /\s*(?<name>.*):\s+line\s(?<line>\d+),\s+column\s+(?<col>\d+)/

        def initialize(verbosity)
          @action = 'Generating'
          @pattern = TOOL_PATTERN
          @tool_verbosity = 2
          @verbosity = verbosity
        end

        # override
        def output_patterns
          OUTPUT_PATTERNS
        end

        # override
        def filter_output(s)
          matched_category,_ = output_patterns.detect do |cat, re|
            if rem = re.match(s)
              unless cat == :ignore
                @last_error_desc = rem.names.include?('desc') ? rem[:desc] : rem[0]
              end
            end
            rem
          end
          if matched_category
            @last_output_category = matched_category
            if verbosity > tool_verbosity
              output.println s
            end
            true
          else
            case @last_output_category
              when :error, :warning
                if rem = NEXT_PATTERN.match(s)
                  format_error(@last_output_category, rem, @last_error_desc)
                else
                  output.println s
                end
                true
              else
                false
            end
          end
        end

        private

        def format_error(cat, match, desc)
          plist = [' (ridlc) ']
          plist << ['file: ', green(match[:name]), ' '] if match.names.include?('name')
          plist << ['line: ', green(match[:line])] if match.names.include?('line')
          plist << ' - ' unless plist.empty?
          plist << desc
          case cat
            when :error
              output.print bold(red('ERROR:'))
            when :warning
              output.print bold(yellow('WARNING:'))
            when :info
              output.print bold(blue('INFO:'))
          end
          output.println(plist)
        end

      end # RIDLCompiler

    end # Filter

  end # Project

end # BRIX11
