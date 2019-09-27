#--------------------------------------------------------------------
# @file    msc.rb
# @author  Martin Corino
#
# @brief   Microsoft C/C++ compiler handler for brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
#--------------------------------------------------------------------

module BRIX11

  module Project

    class MSCCompiler < Compiler

      class Filter
        include Formatter::Filter::FilterMethods

        TOOL_PATTERN = /(((?<tool>(cl\.exe))\s((.*\/Fo.*)\s\"(?<cname>([\S]+\.)(c|C|cc|CC|cxx|CXX|cpp|CPP|S|asm))\"))|((?<tool>(link\.exe))\s.*))\Z/
        LINK_PATTERN = /if exist\s.*\smt\.exe\s+\-manifest\s.*\s\-outputresource:\"(?<lname>.*)\"\;\d+\Z/
        OUTPUT_PATTERNS = [
            # compile messages
            [:ignore,   /\S+\.(c|C|cc|CC|cxx|CXX|cpp|CPP|S|asm)\Z/],
            [:error,    /^(?<name>.*)\((?<line>\d+)\):\s+[Ee]rror\s+C\d+:\s+(?<desc>.*)\Z/],
            [:error,    /^(?<name>.*)\((?<line>\d+)\):\s+[Ff]atal\s+error\s+C\d+:\s+(?<desc>.*)\Z/],
            [:warning,  /^(?<name>.*)\((?<line>\d+)\):\s+[Ww]arning\s+C\d+:\s+(?<desc>.*)(\s\[.*\])?\Z/],
            # generic
            [:error,    /^(?<name>.*):\((?<line>\d+)\0:(\d+:)? (?<desc>.*)\Z/],
            [:info,     /^(?<name>.*):\s*(?<desc>.*):$/],
        ]

        def initialize(verbosity)
          @action = nil
          @pattern = TOOL_PATTERN
          @tool_verbosity = 2
          @verbosity = verbosity
        end

        # override
        def output_patterns
          OUTPUT_PATTERNS
        end

        # override
        def report_tool(match)
          unless @action
            @tool = match[:tool] if match.names.include?('tool')
            @action = (@tool =~ /link/ ? 'Linking' : 'Compiling')
            @last_output_category = nil
            return if @action == 'Linking'
          end
          if verbosity >= tool_verbosity
            if verbosity == tool_verbosity
              if match.names.include?('lname')
                output.println bold(tool_action), ": #{match[:lname]}"
              else
                output.println bold(tool_action), ": #{match[:cname]}"
              end
            else
              output.print(bold(tool_action), ': ')
              output.println match.string
            end
          end
          @action = nil
        end

        # override
        def filter_output(s)
          if @action == 'Linking'
            if _m = LINK_PATTERN.match(s)
              report_tool(_m)
              return true
            end
            # no link pattern match yet, ignore this unless verbosity
            return verbosity <= tool_verbosity
          end
          return super
        end

      end # Filter

      # override
      def filter(verbosity)
        Filter.new(verbosity)
      end

    end # MSCCompiler

  end # Project

end # BRIX11


