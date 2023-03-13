#--------------------------------------------------------------------
# @file    formatter.rb
# @author  Martin Corino
#
# @brief   BRIX11 output formatters
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/console'

module BRIX11
  module Formatter
    module Printing
      def output=(out)
        @output = out
      end

      def output
        @output ||= BRIX11::Console
      end

      def print(*args)
        output.print(*args)
      end

      def println(*args)
        output.println(*args)
      end

      def error_print(*args)
        output.error_print(*args)
      end

      def error_println(*args)
        output.error_println(*args)
      end

      def flush
        output.flush if output.respond_to? :flush
      end

      include Screen::ColorizeMethods
    end # Printing

    class Filter

      include Printing

      module FilterMethods
        include Screen::ColorizeMethods

        def verbosity
          @verbosity ||= 1
        end

        def output=(out)
          @output = out
        end

        def output
          @output
        end

        def tool
          @tool
        end

        def tool_action
          @action || 'Executing'
        end

        def tool_pattern
          @pattern
        end

        def tool_verbosity
          @tool_verbosity ||= 1
        end

        def output_patterns
          []
        end

        def report_tool(match)
          @last_output_category = nil
          @tool = match[:tool] if match.names.include?('tool')
          if verbosity >= tool_verbosity
            if verbosity == tool_verbosity
              output.println bold(tool_action), ": #{match.names.include?('name') ? match[:name] : match[0]}"
            else
              output.print(bold(tool_action), ': ')
              output.println match.string
            end
          end
        end

        def match(s)
          if rem = tool_pattern.match(s)
            report_tool(rem)
            return true
          end
          false
        end

        def format_output(cat, match)
          plist = []
          plist << " (#{tool}) "
          plist << ['file: ', green(match[:name]), ' '] if match.names.include?('name')
          plist << ['line: ', green(match[:line])] if match.names.include?('line')
          plist << ' - ' unless plist.empty?
          plist << (match.names.include?('desc') ? match[:desc] : match[0])
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

        def filter_output(s)
          matched_category,_ = output_patterns.detect do |cat, re|
            if rem = re.match(s)
              unless cat == :ignore
                format_output(cat, rem)
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
              output.println s
              true
            else
              false
            end
          end
        end
      end # FilterMethods

      def initialize(filters, verbosity = 1)
        @filters = filters
        @filters.each { |flt| flt.output = self.output }
        @cache = nil
        @active_filter = nil
        @verbosity = verbosity
      end

      # override
      def print(*args)
        txt = ((@cache || '') << args.flatten.join)
        lines = txt.split("\n")
        # cache last line if NOT ended by "\n"
        @cache = lines.pop unless /\n$/ =~ txt
        lines.each { |ln| filter_line(ln) }
      end

      # override
      def println(*args)
        print(*args, "\n")
      end

      # override
      def flush
        filter_line(@cache) if @cache
        @cache = nil
      end

      protected

      def filter_line(s)
        # check if this line is recognized as starting output for a (new) filter
        if matched_filter = @filters.detect { |flt| flt.match(s) }
          BRIX11.log(2, "matched tool pattern for #{matched_filter.class.inspect}")
          @active_filter = matched_filter
        else
          filtered = false
          # see if active filter recognizes output
          filtered = @active_filter.filter_output(s) if @active_filter
          # if not let all other filters have a go
          unless filtered
            cur_filter = @active_filter
            @active_filter = @filters.find do |flt|
              cur_filter != flt && flt.filter_output(s)
            end
            BRIX11.log(2, "matched output for #{@active_filter.class.inspect}") if @active_filter
            filtered = !@active_filter.nil?
          end
          # check if we should provide verbose output for non-filtered lines
          output.println(s) unless filtered || @verbosity <= 1
          # reset active filter if the last line was not recognized by it
          #@active_filter = nil unless filtered
        end
      end

    end # Filter

    class Tee

      include Printing

      def initialize(logfile, out = nil)
        @logfile = logfile
        @output = out
      end

      # override
      def print(*args)
        @logfile.print args.flatten.join
        super
      end

      # override
      def println(*args)
        @logfile.puts args.flatten.join
        super
      end

      # override
      def error_print(*args)
        @logfile.print args.flatten.join
        super
      end

      # override
      def error_println(*args)
        @logfile.puts args.flatten.join
        super
      end

    end
  end # Formatter
end # BRIX11
