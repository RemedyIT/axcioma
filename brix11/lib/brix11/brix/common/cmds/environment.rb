#--------------------------------------------------------------------
# @file    environment.rb
# @author  Martin Corino
#
# @brief  Help command for brix scaffolding tool.
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/command'

module BRIX11
  module Common

    class Environment  < Command::Base

      DESC = 'Print BRIX11 environment settings for development.'.freeze

      OPTIONS = {
      }

      def self.setup(optparser, options)
        options[:environment] = OPTIONS.dup
        optparser.banner = "#{DESC}\n\nUsage: #{options[:script_name]} environment [options]\n\n"
        optparser.on('-A', '--all',
                     'Specifies to print all environment variables.',
                     'Default: print only BRIX11 specific environment') {|v|
          options[:environment][:full] = true
        }
        optparser.on('-f', '--file', '=FILE',
                     'Specifies filename to write environment settings to.',
                     'Default: print to console') {|v|
                        options[:environment][:file] = v
                     }
      end

      def run(argv)
        envs =
          (options[:environment][:full] ? Exec.full_environment : Exec.run_environment).sort do |(ka,_),(kb,_)|
                ka <=> kb
              end.collect {|(key, val)| Sys.environment_command(key, val) }.join("\n")
        if options[:environment][:file]
          File.open(options[:environment][:file], 'w') {|f| f.puts envs }
        else
          self.println(envs)
        end
        true
      end

      Command.register('environment', DESC, Common::Environment)
    end # Environment

  end # Common
end # BRIX11