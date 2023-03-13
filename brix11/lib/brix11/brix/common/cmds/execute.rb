#--------------------------------------------------------------------
# @file    execute.rb
# @author  Martin Corino
#
# @brief  Help command for brix scaffolding tool.
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/command'

module BRIX11
  module Common
    class Execute < Command::Base

      DESC = 'Execute a process in the brix11 environment.'.freeze

      OPTIONS = {
      }

      def self.setup(optparser, options)
        options[:execute] = OPTIONS.dup
        optparser.banner = "#{DESC}\n\nUsage: #{options[:script_name]} execute [options] PROGRAM [arguments [--]]\n\n"
        optparser.on('-d', '--detach',
                     'Specifies to detach from child process after execution.',
                     'Default: wait for child process to terminate') { |v|
                        options[:execute][:detach] = true
                     }
        optparser.on('-C', '--capture', '=FILE',
                     'Capture output from child process to file FILE.',
                     'Default: no output capture') { |v|
          options[:execute][:capture] = v
          options[:execute][:noredirect] = false
        }
        optparser.on('-N', '--no-redirect',
                     'Do not redirect output from child process..',
                     'Default: redirect (and optionally filter or capture) output.') { |v|
          options[:execute][:noredirect] = true
          options[:execute][:capture] = nil
        }
      end

      class Redirect
        include Formatter::Printing
      end

      def run(argv)
        argv ||= []
        if argv.empty? || argv.first.start_with?('-')
          log_error('Missing PROGRAM.')
          return false
        else
          options[:execute][:program] = argv.shift
        end
        options[:execute][:args] = []
        while !argv.empty? && argv.first != '--'
          options[:execute][:args] << argv.shift
        end
        runopts = {}
        if options[:execute][:capture]
          runopts[:capture] = options[:execute][:capture].to_s
        else
          runopts[:filter] = Redirect.new unless options[:execute][:noredirect]
        end
        runopts[:detach] = options[:execute][:detach]
        rc, exitcode, _ = Exec.runcmd(options[:execute][:program],
                                      *options[:execute][:args],
                                      runopts)
        rc
      end

      Command.register('execute', DESC, Common::Execute)
    end # Execute
  end # Common
end # BRIX11
