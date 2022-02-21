#--------------------------------------------------------------------
# @file    bootstrap.rb
# @author  Martin Corino
#
# @brief  Bootstrap tool
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/command'
require 'fileutils'
module BRIX11
  module Common

    class BootStrap  < Command::Base

      DESC = 'Bootstrap the project.'.freeze

      OPTIONS = {
        :target => 'AXCIOMA',
        :tags => {}
      }

      def self.setup(optparser, options)
        options[:bootstrap] = OPTIONS.dup
        optparser.banner = "#{DESC}\n\n"+
                           "Usage: #{options[:script_name]} bootstrap [TARGET] [options]\n\n"+
                           "       TARGET := Target component collection to bootstrap. Supported:\n"+
                           "                 taox11 \tBootstraps solely the TAOX11 framework components\n"+
                           "                 axcioma\tBootstraps the AXCIOMA framework components (default)\n\n"

        optparser.on('-t', '--tag', '=COMPONENT:TAG', String, 'Override default repository tags for framework components.',
                                                              'Specify as <component id>:<tag>. Supported components:',
                                                              "ACE\tDOC Group ACE + TAO repository",
                                                              "MPC\tDOC Group MPC repository",
                                                              "ridl\tRIDL IDL compiler frontend",
                                                              "taox11\tTAOX11 C++11 CORBA ORB repository",
                                                              "ciaox11\tCIAOX11 C++11 LwCCM repository",
                                                              "dancex11\tDANCEX11 C++11 D&C repository") do |v|
          id, tag = v.split(':')
          BRIX11.log_fatal("Missing required tag for component in [--tag #{v}].") unless tag
          options[:bootstrap][:tags][id] = tag
        end
      end

      def run(argv)
        argv ||= []
        unless argv.empty? || Command.is_command_arg?(argv.first, options) || argv.first.start_with?('-')
          # we have a target name specified
          options[:bootstrap][:target] = argv.shift.upcase
        end
        # no target name specified or extracted so what follows should be either '--' (and than some) or nothing at all
        # make sure we shift up to the '--' (or end)
        argv.shift unless argv.empty? || argv.first == '--'

        BRIX11.show_msg("Bootstrapping #{options[:bootstrap][:target]} framework")
        Sys.in_dir(File.dirname(BRIX11_BASE_ROOT)) do

          (BRIX11.options.config.bootstrap || []).each do |bse|
            if bse['collections'].any? { |coll| options[:bootstrap][:target] == coll.upcase }
              BRIX11.show_msg("Bootstrapping #{bse['id']} component")
              BRIX11.log_fatal('Invalid bootstrap entry. Missing target folder.') unless bse['dir']
              BRIX11.log_fatal('Invalid bootstrap entry. Missing repository URL.') unless bse['repo']
              Sys.mkdir(bse['dir'])
              Sys.in_dir(bse['dir']) do
                tag = bse['tag'] || options[:bootstrap][:tags][bse['id']] || 'master'
                rc, _, _ = Exec.runcmd('git', 'clone', bse['repo'], '.')
                BRIX11.show_msg("Failed to clone #{bse['id']} repository : #{bse['repo']}") unless rc
                rc,_, _ = Exec.runcmd('git', 'checkout', tag)
                BRIX11.log_fatal("Failed to checkout #{bse['id']} repository tag : #{tag}") unless rc
              end
            end
          end

        end

        BRIX11.show_msg('Bootstrapping finished. Exiting BRIX11.')
        exit(0)
      end

    end # BootStrap

    Command.register('bootstrap', BootStrap::DESC, Common::BootStrap)

  end # Common

end # BRIX11
