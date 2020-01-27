#--------------------------------------------------------------------
# @file    hostbuild.rb
# @author  Martin Corino
#
# @brief  Build crossbuild host tools
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/command'
require 'fileutils'
module BRIX11
  module Common

    class HostBuild  < Command::Base

      DESC = 'Build crossbuild host tools.'.freeze

      OPTIONS = {
        build: true,
        clean: false
      }

      def self.setup(optparser, options)
        options[:hostbuild] = OPTIONS.dup
        optparser.banner = "#{DESC}\n\n"+
                           "Usage: #{options[:script_name]} host build [options] [-- make-options]\n\n"

        optparser.on('-c', '--clean', 'Clean only.') { options[:hostbuild][:clean] = true; options[:hostbuild][:build] = false }
        optparser.on('-r', '--rebuild', 'Clean and than build.') { options[:hostbuild][:clean] = true; options[:hostbuild][:build] = true }
        optparser.on('-G', '--generate', 'Always (re-)generate project files',
                                         'Default: only generate if project files do not exist.') do
          options[:hostbuild][:generate] = true
        end
        optparser.on('-N', '--no-redirect',
                     'Do not redirect output from child process..',
                     'Default: redirect and filter output.')  do
          options[:hostbuild][:noredirect] = true
        end
      end

      def run(_argv)
        # get make's own options/arguments
        # skip the '--' (if any)
        if !argv.empty? && argv.first == '--'
          argv.shift
        end
        # only arguments after PROJECT or after '--' are remaining, now gather unless arg is new brix command
        options[:hostbuild][:make_opts] ||= []
        while !(argv.empty?)
          break if Command.is_command_arg?(argv.first, options)
          options[:hostbuild][:make_opts] << argv.shift
        end

        host_root = File.join(Exec.get_run_environment('X11_BASE_ROOT'), Configure::HostSetup::FOLDER, 'ACE')
        BRIX11.show_msg("Building crossbuild host tools.")
        rc = true

        Sys.in_dir(host_root) do
          host_env = {
              'ACE_ROOT' => File.join(host_root, 'ACE'),
              'TAO_ROOT' => File.join(host_root, 'TAO'),
              'MPC_ROOT' => Exec.get_run_environment('MPC_ROOT'),
          }
          prj = Project.handler('gnuautobuild')
          prjargv = []
          log(2, "checking for gnuautobuild type project")
          if options[:hostbuild][:generate] || (!prj.project_exists?(*prjargv) && options[:hostbuild][:build])
            opts = {
              project: Configure::HostSetup::MWC,
              mpc_path: File.join(host_root, 'ACE', 'bin'),
              env: host_env,
              overwrite_env: true
            }
            rc = prj.generate(opts, prjargv)
            raise Command::CmdError, 'Failed to generate project files.' unless rc
          end
          opts = options.to_h.merge!({
                    project: Configure::HostSetup::MWC,
                    env: host_env,
                    overwrite_env: true,
                    make: { noredirect: options[:hostbuild][:noredirect], make_opts: options[:hostbuild][:make_opts] }
                  })
          prjargv << opts
          rc = prj.clean([], *prjargv) if options[:hostbuild][:clean]
          rc = prj.build([],*prjargv ) if rc && options[:hostbuild][:build]
          log_error('Failed to make hosttools') unless rc
        end

        rc
      end

      def self.activate
        if BRIX11.options.config.crossbuild
          x11_host_root = File.join(Exec.get_run_environment('X11_BASE_ROOT'), Configure::HostSetup::FOLDER)
          if File.directory?(x11_host_root) && File.file?(File.join(x11_host_root, 'ACE', "#{Configure::HostSetup::MWC}.mwc"))
            Command.register('host:build', HostBuild::DESC, Common::HostBuild)
          end
        end
      end

    end # BootStrap

  end # Common

end # BRIX11
