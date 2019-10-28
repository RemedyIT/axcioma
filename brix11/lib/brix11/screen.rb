#--------------------------------------------------------------------
# @file    screen.rb
# @author  Martin Corino
#
# @brief   BRIX11 screen wrapper
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/system'

module BRIX11

  class Screen

    class Color
      def initialize(code)
        @code = code
      end
      attr_reader :code
      def to_s
        ''
      end
      alias :to_str :to_s
    end

    COLORS = {
      black:    [Color.new("\e[30m"), Color.new("\e[m")],
      red:      [Color.new("\e[31m"), Color.new("\e[m")],
      green:    [Color.new("\e[32m"), Color.new("\e[m")],
      yellow:   [Color.new("\e[33m"), Color.new("\e[m")],
      blue:     [Color.new("\e[34m"), Color.new("\e[m")],
      magenta:  [Color.new("\e[34m"), Color.new("\e[m")],
      bold:     [Color.new("\e[1m"),  Color.new("\e[m")],
      reverse:  [Color.new("\e[7m"),  Color.new("\e[m")],
      underline:[Color.new("\e[4m"),  Color.new("\e[m")]
    }

    module ColorizeMethods
      def self.included(mod)
        Screen::COLORS.keys.each do |color|
          mod.module_eval <<-EOT, __FILE__, __LINE__+1
            def #{color}(s)
              [BRIX11::Screen::COLORS[:#{color}].first, s, BRIX11::Screen::COLORS[:#{color}].last]
            end
          EOT
        end
      end
    end

    def initialize(output = STDOUT, input = STDIN, errout = STDERR)
      @output = output
      @input = input
      @errout = errout
      @colorize = output.tty? && BRIX11::Sys.has_ansi?
    end

    attr_reader :input, :output, :errout

    def colorize?
      @colorize
    end

    def output_cols
      80
    end

    # COLORS.keys.each do |color|
    #   class_eval <<-EOT, __FILE__, __LINE__+1
    #     def #{color}(s)
    #       colorize? ? [COLORS[:#{color}].first, s, COLORS[:#{color}].last] : s
    #     end
    #   EOT
    # end

    def print(*args)
      output.print args.flatten.collect {|a| (colorize? && Color === a) ? a.code : a }.join
    end

    def println(*args)
      output.puts args.flatten.collect {|a| (colorize? && Color === a) ? a.code : a }.join
    end

    def error_print(*args)
      errout.print args.flatten.collect {|a| (colorize? && Color === a) ? a.code : a }.join
    end

    def error_println(*args)
      errout.puts args.flatten.collect {|a| (colorize? && Color === a) ? a.code : a }.join
    end


    def list(lst, mode = :rows, *rest)
      lst.collect { |li| [li, "\n"] }
    end

    class Question
      attr_accessor :default, :character, :validate
      def responses
        @responses ||= {}
      end
    end

    def ask(question, type = String)
      q = Question.new
      yield(q) if block_given?
      println(question, q.default ? " |#{q.default}|" : '', "\n")
      ans = nil
      begin
        ans = input.gets.strip
        unless ans.empty? || q.validate.nil? || (q.validate =~ ans)
          println(q.responses[:not_valid] || 'ERROR', "\n")
          println(*([q.responses[:ask_on_error]] || [question, q.default ? " |#{q.default}|" : '']), "\n")
          ans = nil
        end
      end while ans.nil?
      ans.empty? ? q.default.to_s.strip : ans
    end

    def agree(question, ch)
      ans = ask(question).upcase
      %w(Y YES).include?(ans)
    end

    class Menu < Question
      attr_accessor :layout, :index, :select_by, :header, :prompt, :nil_on_handled
      def update_responses
        responses[:ambiguous_completion] = 'Ambiguous entry'
        responses[:no_completion] = 'Unknown entry'
      end
      def choices
        @choices ||= []
      end
      def choice(sel, name, &action)
        choices << [sel, name, action]
      end
    end

    def choose(*items, &details)
      m = Menu.new
      m.choices.concat(items)
      yield(m) if block_given?
      m.update_responses
      println(m.header)
      println(list(m.choices.collect {|c| c[1] }))
      println(m.prompt)
      begin
        ans = input.gets.strip
        ans = ans.empty? ? q.default.to_s.strip : ans
        sel = m.choices.find_all { |c| /^#{ans}/ =~ c[0] ? true : false }
        if sel.size == 1
          sel = sel.shift
          return (if sel[1]
                    sel = sel[1].call(sel[0])
                    m.nil_on_handled ? nil : sel
                  else
                    sel[0]
                  end)
        else
          println(sel.empty? ? m.responses[:no_completion] : m.responses[:ambiguous_completion])
          output.print '? '
        end
      end while true
    end

  end

end