#--------------------------------------------------------------------
# @file    console.rb
# @author  Martin Corino
#
# @brief   BRIX11 console wrapper
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/screen'

module BRIX11
  module Console
    class << self
      def screen
        @screen ||= Screen.new(BRIX11.options[:output] || $stdout, $stdin)
      end
      include Screen::ColorizeMethods
    end

    def self.print(*args)
      screen.print(*args)
    end

    def self.println(*args)
      screen.println(*args)
    end

    def self.error_print(*args)
      screen.error_print(*args)
    end

    def self.error_println(*args)
      screen.error_println(*args)
    end

    def self.display_break
      println("\n")
    end

    def self.display_hline(len = nil)
      println("#{'-' * (len || [80, (screen.output_cols / 5 * 4)].min)}\n")
    end

    class Text
      include Screen::ColorizeMethods

      LABEL_SEPARATOR = ': ' unless defined? LABEL_SEPARATOR

      @@label_format = nil
      @@indent = 0

      def self.on_label_format(fmt_or_proc, &block)
        @@label_format = if block_given?
          block
        else
          fmt_or_proc
        end
      end

      def self.label_format=(fmt)
        on_label_format(fmt)
      end

      def self.indent=(i)
        @@indent = i.to_i
      end

      def self.indent
        @@indent
      end

      def initialize(text, options_or_hdr = {})
        @text = text.to_s
        options_or_hdr ||= {}
        @label = (Hash === options_or_hdr ? options_or_hdr[:label] : options_or_hdr)
        @label_fmt = (Hash === options_or_hdr ? options_or_hdr[:label_fmt] : nil)
        @indent = (Hash === options_or_hdr ? options_or_hdr[:indent] : nil)
      end

      attr_reader :label

      def indent
        (@indent || @@indent).to_i
      end

      def indent=(i)
        @indent = i.to_i
      end

      def label_format
        @label_fmt || @@label_format || '%s'
      end

      def label_format_str
        (@label_fmt && !(Proc === @label_fmt)) ? @label_fmt : ((@@label_format && !(Proc === @@label_format)) ? @@label_format : '%s')
      end

      def label_format=(fmt_or_proc, &block)
        @label_fmt = if block_given?
          block
        else
          fmt_or_proc
        end
      end
      alias :on_label_format :label_format=

      def text_width
        if @label
          unless @label_fmt == false
            lf = label_format
            (Proc === lf ? lf.call(self) : (lf % @label)).size
          else
            @label.to_s.size
          end + LABEL_SEPARATOR.size
        else
          0
        end + @text.size
      end

      def text
        txt = [' ' * indent]
        if @label
          unless @label_fmt == false
            lf = label_format
            txt << bold(Proc === lf ? lf.call(self) : (lf % @label))
          else
            txt << bold(@label.to_s)
          end
          txt << LABEL_SEPARATOR
        end
        txt << @text
      end
    end # Text

    def self.display_text(text, options = {})
      screen.println(*(Text === text ? text.text : Text.new(text.to_s, options || {}).text))
    end

    def self.display_alert(text)
      display_text(text, label: 'NOTICE', label_fmt: proc { |t| yellow(reverse(t.label_format_str % t.label)) })
    end

    def self.display_warning(text)
      display_text(text, label: 'WARNING', label_fmt: proc { |t| red(reverse(t.label_format_str % t.label)) })
    end

    def self.confirm(prompt, options = {})
      options ||= {}
      indent = (options[:indent] || Text.indent).to_i
      ans_opt = nil
      cvt_proc = nil
      val_exp = nil
      unless options[:default].nil?
        ans_opt = options[:default] ? 'Y/n' : 'y/N'
        cvt_proc = options[:default] ? proc { |yn| yn.empty? || yn.downcase[0] == 'y' } : proc { |yn| !yn.empty? && yn.downcase[0] == 'y' }
        val_exp = /(^y(?:es)?|no?$)|(^\s*$)/i
      else
        ans_opt = 'y/n'
        cvt_proc = proc { |yn| yn.downcase[0] == 'y' }
        val_exp = /^y(?:es)?|no?$/i
      end
      screen.ask("#{' ' * indent}#{bold(prompt)}? [#{ans_opt}] ", cvt_proc) do |q|
        q.validate                 = val_exp
        q.responses[:not_valid]    = "#{' ' * indent}Please enter 'y(es)' or 'n(o)'."
        q.responses[:ask_on_error] = [' ' * indent, bold(prompt), '? ']
        q.character                = nil
      end
    end

    class Menu
      include Screen::ColorizeMethods

      def initialize(header, options = {})
        @stop = false
        options ||= {}
        @indent = options[:indent] || 0
        @prompt = [' ' * @indent, (options[:prompt] || 'Select option:'), ' ']
        @select_by = options[:select_by] || :name
        @header = bold "#{' ' * @indent}#{(header || 'Menu:')}"
        @help = "#{' ' * @indent}Enter "
        @entries = {}
      end

      attr_reader :header, :prompt, :select_by, :indent, :entries
      attr_accessor :choice

      def before_menu(&block)
        @before = block
      end

      def after_menu(&block)
        @after
      end

      def do_before
        @before.call(self) if @before
      end

      def do_after
        @after.call(self) if @after
      end

      class Entry
        def initialize(menu, txt, options = {})
          @menu = menu
          @text = txt.to_s
          options ||= {}
          @name = options[:name] || @text.split.first.to_s
          @proc = options[:proc]
          @enabled = options[:enabled].nil? ? true : options[:enabled]
          _ind = ' ' * menu.indent
          if @menu.select_by == :name
            @ch = @text
            @text = ["#{@text[0, 1]}\r#{_ind}", bold(@text[0, 1]), @text[1..-1]]
          else
            @ch = "#{@menu.entries.size + 1}"
            @text = [_ind, bold(@ch), @text]
          end
        end

        attr_reader :menu, :name, :text, :ch

        def enabled?
          Proc === @enabled ? @enabled.call(self) : @enabled
        end

        def enabled=(bool_or_proc = nil, &block)
          @enabled = if block_given?
            block
          else
            (Proc === bool_or_proc ? bool_or_proc : (bool_or_proc ? true : false))
          end
        end
        alias :on_enabled :enabled=

        def enable
          @enabled = true
        end

        def disable
          @enabled = false
        end

        def execute
          @menu.choice = @name
          if @proc
            @proc.call(self)
          else
            @menu.stop
          end
        end

        def stop
          @menu.stop
        end
      end

      def add_entry(txt, options = {}, &prc)
        entry = Entry.new(self, txt, (options || {}).merge({ proc: prc }))
        @entries[entry.name] = entry
      end

      def help
        _help = [@help.dup]
        _hsep = ''
        @entries.each do |n, entry|
          if entry.enabled?
            _help << _hsep
            _help << "#{entry.ch} for " << entry.name
            _hsep = ', '
          end
        end
        _help
      end

      def stop
        @stop = true
      end

      def restart
        @stop = false
        @choice = nil
      end

      def stop_called?
        @stop
      end
    end # Menu

    # run given Console::Menu definition
    #
    def self.run_menu(menudef)
      _last_choice = nil
      menudef.restart
      begin
        menudef.do_before
        screen.choose do |_menu|
          class << _menu
            def set_menu_def(menudef)
              @_menudef = menudef
            end

            def update_responses
              super
              @responses[:ambiguous_completion] = @_menudef.help
              @responses[:no_completion] = @_menudef.help
              @responses[:ask_on_error] = "#{' ' * @_menudef.indent}? "
            end
          end
          _menu.set_menu_def(menudef)
          _menu.layout = :list
          _menu.index = menudef.select_by == :name ? :none : :number
          _menu.select_by = menudef.select_by
          _menu.header = menudef.header
          _menu.prompt = menudef.prompt
          menudef.entries.each do |_mname, _entry|
            if _entry.enabled?
              _menu.choice(_entry.ch, _entry.text) { _entry.execute }
            end
          end
        end
        menudef.do_after
      end while !menudef.stop_called?
    end

    class List
      include Screen::ColorizeMethods

      def initialize(items, options = {})
        @items = items
        @count = if items.respond_to?(:size)
          items.size
        else
          _count = 0
          items.each { |i| _count += 1 }
          _count
        end
        _hdr = options[:header]
        @header = _hdr ? (Hash === _hdr ? Text.new("\n", _hdr) : Text.new("\n", { label: _hdr.to_s })) : nil
        @size = options[:size]
        @format = options[:format]
        @fmtstr = "%#{@count.to_s.size}s" if @format == :numbered
        @indent = (options[:indent] || 0).to_i
        @sort = options[:sort]
      end

      attr_reader :header, :count, :indent

      def size=(sz_or_proc = nil, &block)
        @size = if block_given?
          block
        else
          sz_or_proc
        end
      end
      alias :on_size :size=

      def format=(fmt_or_proc = nil, &block)
        @format = if block_given?
          block
        else
          fmt_or_proc
        end
        @fmtstr = "%#{@count.to_s.size}s" if @format == :numbered
      end
      alias :on_format :format=

      def sort=(f_or_proc = nil, &block)
        @sort = if block_given?
          block
        else
          f_or_proc
        end
      end
      alias :on_sort :sort=

      def content
        # determin maximum item size
        _item_nr = 0
        _item_texts = item_list.collect { |itm| _item_nr += 1; formatted_item(_item_nr, itm) }
        _content = if @count <= 20
          Console.screen.list(_item_texts, :rows, nil)
        else
          _max_size = @items.collect { |itm| item_size(itm) }.max + 4
          _col_nr = (Console.screen.output_cols / (_max_size + 3))
          Console.screen.list(_item_texts, :columns_down, _col_nr)
        end
        _content.collect! { |l| [' ' * @indent, l] } if @indent > 0
        _content
      end

    private
      def item_to_s(item)
        [item].flatten.join
      end

      def item_list
        if Proc === @sort
          @items.sort { |a, b| @sort.call(a, b) }
        elsif @sort
          @items.sort { |a, b| item_to_s(a) <=> item_to_s(b) }
        else
          @items
        end
      end

      def item_size(item)
        if Proc === @size
          @size.call(item)
        elsif Integer === @size
          @size
        elsif @format == :numbered
          item_to_s(item).size + 2 + (@count.to_s.size)
        else
          item_to_s(item).size
        end
      end

      def formatted_item(index, item)
        if Proc === @format
          @format.call(index, item)
        elsif @format == :numbered
          [bold(@fmtstr % index), '.', item]
        elsif String === @format
          @format % [index.to_i, item_to_s(item)]
        else
          item_to_s(item)
        end
      end
    end # List

    def self.display_list(list)
      display_text(list.header) if list.header
      screen.println(list.content, "\n")
    end

    def self.select_multiple(list, prompt = nil)
      list.format = :numbered
      list.size = nil
      display_list(list)
      prompt ||= "Enter 1 or more nrs or 'a(ll)' and press [Enter]. Leave empty to quit."
      prompt = "#{' ' * list.indent}#{prompt}\n#{' ' * list.indent}? "
      begin
        txt = screen.ask(prompt, String).strip
        sel = if /^(\s|\d)+$/ =~ txt
          txt.split.collect { |a| a.to_i - 1 }
        elsif /^a(l|ll)?$/ =~ txt
          (0...list.count).to_a
        elsif txt.empty?
          []
        end
        if Array === sel
          sel.uniq!
          if sel.empty? || sel.all? { |i| (0...list.count) === i }
            display_break
            return sel
          end
        end
        println(red 'Error:', "Invalid selection entered [#{txt}]")
      end while true
    end
  end # Console
end # BRIX11
