#--------------------------------------------------------------------
# @file    help.rb
# @author  Martin Corino
#
# @brief  Help command for brix scaffolding tool.
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/command'
require 'rdoc'

module BRIX11
  module Common
    class Help < Command::Base
      DESC = 'Show help (documentation) for brix11 (command).'.freeze

      OPTIONS = {}

      MAIN_HELP = File.join(BRIX11_BASE_ROOT, 'lib', 'brix11', 'docs', 'brix.rd')

      def self.setup(optparser, options)
        options[:help] = OPTIONS.dup
        optparser.banner = "#{DESC}\n\nUsage: #{options[:script_name]} help [command]\n\n"
      end

      def run(argv)
        if argv.empty? || argv.first.start_with?('-')
          # default help page
          fhlp = MAIN_HELP
          if File.file?(fhlp)
            data = File.read(fhlp)
          else
            log_error("Cannot access help file #{fhlp}")
            return false
          end
        else
          # find command
          cmd = Command.parse_command(argv, options)
          # determin help page name
          fhlp = File.join(Collection[cmd.collection].root, 'docs', "#{cmd.scoped_id.gsub(':', '_')}.rd")
          if File.file?(fhlp)
            data = File.read(fhlp)
          else
            # generate default help
            data = "\n= BRIX11 #{cmd.id} command\n\n== Collection\n\n  #{cmd.collection}\n\n== Usage\n\n"
            data << "  brix11 #{cmd.scoped_id.gsub(':', ' ')} [options]\n\n=== options\n"
            optparser = Command.init_optparser(options)
            cmd.klass.setup(optparser, options)
            optparser.banner = ''
            data << optparser.to_s << "\n\n== Description\n\n" << cmd.desc << "\n"
          end
        end
        formatter = Sys.has_ansi? ? RDoc::Markup::ToAnsi.new() : RDoc::Markup::ToRdoc.new()
        text = RDoc::RD.parse(data).accept(formatter)
        text = text.split("\n").collect { |l| "  #{l}" }.join("\n")
        text << "\n\n"
        Exec.runcmd(Sys.pager, input: text, silent: true)
        true
      end

      Command.register('help', DESC, Common::Help)
    end # Help
  end # Common
end # BRIX11
