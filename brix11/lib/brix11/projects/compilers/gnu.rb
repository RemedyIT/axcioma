#--------------------------------------------------------------------
# @file    gnu.rb
# @author  Martin Corino
#
# @brief   GNU compiler handler for brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module BRIX11

  module Project

      class GNUCompiler < Compiler

        class Filter
          include Formatter::Filter::FilterMethods

          TOOL_PATTERN = /(?<tool>(gcc)|([gc]\+\+)|(clang))\s(((.*-c\s.*)\s(?<cname>([\S]+\.)(c|C|cc|CC|cxx|CXX|cpp|CPP|S|asm)))|((.*-o\s(?<lname>\S+)\s)(.*(-Wl,|-L|-l)\S+\s.*)))\Z/
          OUTPUT_PATTERNS = [
              # compile messages
              [:ignore,   /(.*?):(\d+):(\d+:)? .*\(Each undeclared identifier is reported only once.*/],
              [:ignore,   /(.*?):(\d+):(\d+:)? .*for each function it appears in.\).*/],
              [:ignore,   /(.*?):(\d+):(\d+:)? .*this will be reported only once per input file.*/],
              [:error,    /(?<name>^.*?):(?<line>\d+):(\d+:)? [Ee]rror: (?<desc>[`'"](.*)['"] undeclared .*)/],
              [:error,    /(?<name>^.*?):(?<line>\d+):(\d+:)? [Ee]rror: (?<desc>conflicting types for .*[`'"](.*)['"].*)/],
              [:error,    /(?<name>^.*?):(?<line>\d+):(\d+:)? (?<desc>parse error before.*[`'"](.*)['"].*)/],
              [:warning,  /(?<name>^.*?):(?<line>\d+):(\d+:)? [Ww]arning: (?<desc>[`'"](.*)['"] defined but not used.*)/],
              [:warning,  /(?<name>^.*?):(?<line>\d+):(\d+:)? [Ww]arning: (?<desc>conflicting types for .*[`'"](.*)['"].*)/],
              [:warning,  /(?<name>^.*?):(?<line>\d+):(\d+:)? ([Ww]arning:)?\s*(?<desc>the use of [`'"](.*)['"] is dangerous, better use [`'"](.*)['"].*)/],
              [:info,     /(?<name>^.*?):(?<line>\d+):(\d+:)?\s*(?<desc>.*((instantiated)|(required)) from .*)/],
              [:error,    /(?<name>^.*?):(?<line>\d+):(\d+:)?\s*(([Ee]rror)|(ERROR)): (?<desc>.*)/],
              [:warning,  /(?<name>^.*?):(?<line>\d+):(\d+:)?\s*(([Ww]arning)|(WARNING)): (?<desc>.*)/],
              [:info,     /(?<name>^.*?):(?<line>\d+):(\d+:)?\s*(([Nn]ote)|(NOTE)|([Ii]nfo)|(INFO)): (?<desc>.*)/],
              [:info,     /(?<desc>In file included from) (?<name>.*):(?<line>\d+):\d+:$/],
              # link messages
              [:info,       /(?<name>^.*?):?(\(\.\w+\+.*\))?:\s*(?<desc>[Ii]n function [`'"](.*)['"]:)/],
              [:info,       /(?<name>^.*?):(?<line>\d+):(\d+:)? (?<desc>first defined here.*)/],
              [:warning,    /(?<name>^.*?):(?<line>\d+):(\d+:)? ([Ww]arning:)?\s*(?<desc>the use of [`'"](.*)['"] is dangerous, better use [`'"](.*)['"].*)/],
              [:warning,    /(?<name>^.*?):?\(\.\S+\+.*\): [Ww]arning:? (?<desc>.*)/],
              [:error,      /(?<name>^.*?):?\(\.\S+\+.*\): (?<desc>.*)/],
              [:error,      /(?<name>^.*?):(?<line>\d+):(\d+:)? (?<desc>.*)/],
              [:warning,    /(.*[\/\\])?ld(\.exe)?:\s*(?<desc>skipping incompatible.*)/],
              [:warning,    /(.*[\/\\])?ld(\.exe)?:\s*[Ww]arning:? (?<desc>.*)/],
              [:error,      /(.*[\/\\])?ld(\.exe)?:\s*(?<desc>.*)/],
              # generic
              [:error,    /(?<name>^.*?):(?<line>\d+):(\d+:)? (?<desc>.*)/],
              [:info,     /(?<name>^.*?):\s*(?<desc>.*):$/],
          ]

          def initialize(verbosity)
            @action = 'Compiling'
            @pattern = TOOL_PATTERN
            @tool_verbosity = 2
            @verbosity = verbosity
          end

          # override
          def output_patterns
            OUTPUT_PATTERNS
          end

          def report_tool(match)
            @action = match[:lname] ? 'Linking' : 'Compiling'
            @last_output_category = nil
            @tool = match[:tool] if match.names.include?('tool')
            if verbosity >= tool_verbosity
              if verbosity == tool_verbosity
                output.println bold(tool_action), ": #{match[:lname] ? match[:lname] : match[:cname]}"
              else
                output.print(bold(tool_action), ': ')
                output.println match.string
              end
            end
          end

        end # Filter

        # override
        def filter(verbosity)
          Filter.new(verbosity)
        end

      end # GNUCompiler

  end # Project

end # BRIX11
