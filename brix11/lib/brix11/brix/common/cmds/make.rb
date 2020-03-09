#--------------------------------------------------------------------
# @file    make.rb
# @author  Marijke Hengstmengel/Martin Corino
#
# @brief   Project builder
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/command'

module BRIX11
  module Common

    class Make  < Command::Base

      DESC = 'Make (build) the project.'.freeze

      OPTIONS = {
        genbuild: true,
        build: true,
        debug: false,
        lists: nil,
        make_opts: []
      }

      def self.setup(optparser, options)
        options[:make] = OPTIONS.dup
        options[:make][:lists] = []
        optparser.banner = "#{DESC}\n\n"+
                           "Usage: #{options[:script_name]} make [options] [PROJECT [make-options]]|[-- make-options]\n\n"+
                           "       PROJECT := Path to project folder or name of subproject. If both PROJECT and SUBPRJ\n"+
                           "                  are specified, PROJECT should be path and SUBPRJ subproject name.\n\n"

        optparser.on('-c', '--clean', 'Clean project only.') { options[:make][:clean] = true; options[:make][:build] = false }
        optparser.on('-r', '--rebuild', 'Clean and than build project.') { options[:make][:clean] = true; options[:make][:build] = true }
        optparser.on('-p', '--project', '=SUBPRJ',
                     'Specifies path to or name of (sub-)project to build.') {|v| options[:make][:subprj] = v }
        optparser.on('--no-gen-build', 'Do not automatically generate build files using MPC if they do not exist yet.') { options[:make][:genbuild] = false }
        optparser.on('--debug', 'Debug build.', 'Default: Off') { options[:make][:debug] = true }
        optparser.on('--release', 'Release build.', 'Default: On') { options[:make][:debug] = false}
        optparser.on('-L', '--build-list', '=BUILDLIST', 'Build the list of projects specified by BUILDLIST.',
                                                         'BUILDLIST specifies a buildlist file and optional root as: [<root>=]<listfile>.',
                                                         'If no root is specified it defaults to the location of the listfile.') do |v|
          list, root = v.split('=').reverse
          list = File.expand_path(list)
          options[:make][:lists] << [root || File.dirname(list), list]
        end
        optparser.on('-N', '--no-redirect',
                     'Do not redirect output from child process..',
                     'Default: redirect and filter output.') do |v|
          options[:make][:noredirect] = true
        end
      end

      def run(argv)
        argv ||= []
        unless argv.empty? || Command.is_command_arg?(argv.first, options) || argv.first.start_with?('-')
          # we have a project name specified
          options[:make][:project] = argv.shift
        else # no project name so what follows should be either '--' (and than some) or nothing at all
          # this should not be necessary but make sure we shift up to the '--' (or end)
          argv.shift unless argv.empty? || argv.first == '--'
        end

        # get make's own options/arguments
        # skip the '--' (if any)
        if !argv.empty? && argv.first == '--'
          argv.shift
        end
        # only arguments after PROJECT or after '--' are remaining, now gather unless arg is new brix command
        options[:make][:make_opts] ||= []
        while !(argv.empty?)
          break if Command.is_command_arg?(argv.first, options)
          options[:make][:make_opts] << argv.shift
        end

        # in case a list (or lists) are specified and no project/subprj
        # we do attempt make a project at all but only the list(s)
        rc = true
        if options[:make][:project] || options[:make][:subprj] || options[:make][:lists].empty?
          prj = Project.handler(options[:config][:project_type], options[:config][:project_compiler])
          prjargv = []
          prjargv << options[:make][:subprj] if options[:make][:subprj]
          prjargv << options[:make][:project] if options[:make][:project]
          log(2, "checking for #{options[:config][:project_type]} type project #{options[:make][:subprj] || options[:make][:project]}#{options[:make][:subprj] ? ' in '+(options[:make][:project] || '.') : ''}")
          unless prj.project_exists?(*prjargv) || ( options[:make][:clean] && !options[:make][:build])
            unless (options[:make][:genbuild])
              log_error('Nothing to build')
              return false
            end
            options[:genbuild] = GenerateBuild::OPTIONS.dup
            options[:genbuild][:project] = options[:make][:project]
            options[:genbuild][:subprj] = options[:make][:subprj]
            return false unless GenerateBuild.new(entry, options).run(nil)
          end
          prjargv << options
          rc = prj.clean(options[:make][:make_opts].dup, *prjargv) if options[:make][:clean]
          rc = prj.build(options[:make][:make_opts].dup,*prjargv ) if rc && options[:make][:build]
          log_error("Executing #{current_cmd} failed.") unless rc
          rc
        end

        # do we have any buildlists specified
        unless options[:make][:lists].nil? || options[:make][:lists].empty?
          rc = ListBuilder.build_all(self)
        end

        rc
      end

      Command.register('make|build', DESC, Common::Make)
    end # Make

    Dir.glob(File.join(ROOT, 'cmds', 'make', '*.rb')).each { |p| require "brix/common/cmds/make/#{File.basename(p)}"}

  end # Common
end # BRIX11
