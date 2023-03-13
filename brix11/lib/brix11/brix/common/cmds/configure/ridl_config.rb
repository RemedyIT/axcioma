#--------------------------------------------------------------------
# @file    ridl_config.rb
# @author  Martin Corino
#
# @brief  Configure tool RIDL config helper
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'json'

module BRIX11
  module Common
    class Configure < Command::Base
      module RIDL_Config
        RIDLRC = '.ridlrc'

        class << self
          private

          def is_base_backend?(be_table, be, base_be)
            # is the base_be part of be's bases?
            return true if be_table[be].include?(base_be)
            # is the base_be part of the bases of be's bases?
            be_table[be].any? { |beb| is_base_backend?(be_table, beb, base_be) }
          end
        end

        def self.create_config(cfg)
          base_root = Configurator::ROOT
          ridlrc = File.join(base_root, RIDLRC)
          # backup current file
          Util.backup_file(ridlrc) unless cfg.dryrun?
          # determine the backend to configure
          ridl_be_list = cfg.cfglist.values.inject({}) do |hsh, mod|      # collect backend table
            hsh.merge!({mod.ridl_backend[:backend] => mod.ridl_backend[:bases]}) if mod.ridl_backend[:backend]
            hsh
          end
          # select the backend to configure
          ridl_be = nil
          ridl_be_list.keys.each do |be|
            # select this backend if none selected yet or if the current backend is a base for this one
            if ridl_be.nil? || is_base_backend?(ridl_be_list, be, ridl_be)
              ridl_be = be
            end
          end
          # collect list of configured be paths of enabled modules relative to location of ridlrc file
          ridl_be_path = cfg.cfglist.values.collect do |mod|
            mod.ridl_be_path.collect { |p| Util.relative_path(p, base_root) }
          end.flatten
          # generate ridlrc file
          BRIX11.show_msg("Creating #{ridlrc}")
          begin
            ridlrc_io = cfg.dryrun? ? STDOUT : File.new(ridlrc, 'w')
            ridlrc_io.puts("#----- #{RIDLRC} -----") if cfg.dryrun?
            ridlrc_io.puts(JSON.pretty_generate({ 'backend' => ridl_be || '',  'be_path' => ridl_be_path }))
          ensure
            ridlrc_io.close unless cfg.dryrun?
          end
        end
      end
    end
  end
end
