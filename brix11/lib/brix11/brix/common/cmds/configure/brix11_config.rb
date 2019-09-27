#--------------------------------------------------------------------
# @file    brix11_config.rb
# @author  Martin Corino
#
# @brief  Configure tool BRIX11 config helper
#
# @copyright Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
#--------------------------------------------------------------------

require 'json'

module BRIX11

  module Common

    class Configure  < Command::Base

      module BRIX11_Config

        BRIX11RC = '.brix11rc'

        def self.create_config(cfg)
          base_root = Configurator::ROOT
          brix11rc = File.join(base_root, BRIX11RC)
          # backup current file
          Util.backup_file(brix11rc) unless cfg.dryrun?
          # determine/validate platform specific project type
          project_type, project_compiler = if cfg.rclist.has_key?(:acetao)
                                             cfg.options[:platform][:project_type].call(
                                                         cfg.options[:bitsize] || cfg.options[:platform][:bits],
                                                         BRIX11.options.user_config.project_type,
                                                         BRIX11.options.user_config.project_compiler)
                                           else
                                             # do not reconfigure project type in a distributed build
                                             if BRIX11.options.user_config.project_compiler
                                               [BRIX11.options.user_config.project_type, BRIX11.options.user_config.project_compiler]
                                             else
                                               [BRIX11.options.user_config.project_type]
                                             end
                                           end
          # collect list of configured be paths of enabled modules relative to location of brix11rc file
          brix_paths = cfg.rclist.values.collect do |rc|
            rc.brix_path.collect {|p| Util.relative_path(p, base_root) }
          end.flatten
          # generate ridlrc file
          BRIX11.show_msg("Creating #{brix11rc}")
          begin
            brix11rc_io = cfg.dryrun? ? STDOUT : File.new(brix11rc, 'w')
            brix11rc_io.puts("#----- #{BRIX11RC} -----") if cfg.dryrun?
            brix11rc_io.puts(JSON.pretty_generate({
                              'project_type' => project_type,
                              'project_compiler' => project_compiler,
                              'brix_paths' => brix_paths,
                              'user_environment' => cfg.user_env }))
          ensure
            brix11rc_io.close unless cfg.dryrun?
          end
        end

      end

    end

  end

end
