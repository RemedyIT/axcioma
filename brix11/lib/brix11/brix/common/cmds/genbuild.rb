#--------------------------------------------------------------------
# @file    genbuild.rb
# @author  Marijke Hengstmengel/Martin Corino
#
# @brief   class for starting the make for all tests and/or
#          examples of taox11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/command'

module BRIX11
  module Common
    class GenerateBuild < Command::Base

      DESC = 'Run MPC to generate build files.'.freeze

      OPTIONS = {}

      def self.setup(optparser, options)
        options[:genbuild] = OPTIONS.dup
        optparser.banner = "#{DESC}\n\n"+
                           "Usage: #{options[:script_name]} gen[erate] build|bld [options] [PROJECT [mwc-options]]|[-- mwc-options]\n\n"+
                           "       PROJECT := Path to project folder or name of subproject. If both PROJECT and SUBPRJ\n"+
                           "                  are specified, PROJECT should be path and SUBPRJ subproject name.\n\n"

        #optparser.on('-r', '--recurse', 'Recurse directories.') { options[:genbuild][:recurse] = true }
        optparser.on('-S', '--static', 'Generate for static build.') { options[:genbuild][:static] = true }
        optparser.on('-e', '--enable', '=FEATURE',
                     'Enable feature(s). If specifying more than 1 separate by \',\'') {|v|
                        options[:genbuild][:features]||={};
                        v.split(',').each { |f| options[:genbuild][:features][f] = 1 }
                     }
        optparser.on('-d', '--disable', '=FEATURE',
                     'Disable feature(s). If specifying more than 1 separate by \',\'') {|v|
                        options[:genbuild][:features]||={};
                        v.split(',').each { |f| options[:genbuild][:features][f] = 0 }
                     }
        optparser.on('-p', '--project', '=SUBPRJ',
                     'Specifies path to or name of (sub-)project to generate for.') {|v| options[:genbuild][:subprj] = v }
        optparser.on('-I', '--include', '=DIR',
                     'Include directory.') {|v| options[:genbuild][:include]||=[]; options[:genbuild][:include]<< v }
        optparser.on('-X', '--exclude', '=DIR',
                     'Exclude directory.') {|v| options[:genbuild][:exclude] = ((options[:genbuild][:exclude] || '').split(',') << v).join(',') }
      end

      def run(argv)
        argv ||= []
        unless argv.empty? || Command.is_command_arg?(argv.first, options) || argv.first.start_with?('-')
          options[:genbuild][:project] = argv.shift
        else
          # collect mwc options/arguments
          argv.shift unless argv.empty? || argv.first == '--'
        end

        cmdargv = []

        if !argv.empty? && argv.first == '--'
          argv.shift
        end
        #only argumnets after PROJECT or after '--' are remaining, now gather unless arg is new brix command
        while !argv.empty?
          break if Command.is_command_arg?(argv.first, options)
          cmdargv << argv.shift
        end

        prj = Project.handler(options[:config][:project_type], options[:config][:project_compiler])
        rc = prj.generate(options[:genbuild], cmdargv)
        raise Command::CmdError, "Execution of #{current_cmd} failed." unless rc
        rc
      end

      Command.register('generate:build|bld|make', DESC, Common::GenerateBuild)
    end # Make
  end # Common
end # BRIX11
