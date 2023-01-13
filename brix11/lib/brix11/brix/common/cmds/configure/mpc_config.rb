#--------------------------------------------------------------------
# @file    mpc_config.rb
# @author  Martin Corino
#
# @brief  Configure tool MPC config helper
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module BRIX11

  module Common

    class Configure  < Command::Base

      module MPC_Config

        MPCCFG = 'MPC.cfg'
        MWCCFG = 'workspace'

        def self.create_config(cfg)
          # find MPC base path among active rc specs (only 1 definition allowed)
          mpcbase_rcspec = cfg.cfglist.values.select {|mod| mod.mpc_base }
          BRIX11.log_fatal("Found #{mpcbase_rcspec.size} MPC base paths (in #{mpcbase_rcspec.collect {|rc| rc.mpc_base }.join(" and ")}). Only a single base path definition allowed.") if mpcbase_rcspec.size>1
          BRIX11.log_fatal("Missing MPC base path. At least 1 base path definition required.") if mpcbase_rcspec.empty?
          mpccfg = File.join(mpcbase_rcspec.shift.mpc_base, 'config', MPCCFG)
          # backup current file
          Util.backup_file(mpccfg) unless cfg.dryrun?
          # collect list of configured MPC include folders for enabled modules
          mpcinc = cfg.cfglist.values.collect do |mod|
            mod.mpc_include
          end.flatten
          # collect list of configured MPC dynamic types folders for enabled modules
          mpcdynamic = cfg.cfglist.values.collect do |mod|
            mod.mpc_dynamic_type
          end.flatten
          # generate mpc config file
          BRIX11.show_msg("Creating #{mpccfg}")
          begin
            mpccfg_io = cfg.dryrun? ? STDOUT : File.new(mpccfg, 'wb')
            mpccfg_io.puts("//----- #{MPCCFG} -----") if cfg.dryrun?
            mpccfg_io.puts("includes = #{mpcinc.join(', ')}")
            mpccfg_io.puts("dynamic_types = #{mpcdynamic.join(', ')}")
            mpccfg_io.puts('main_functions = cplusplus:ACE_TMAIN')
          ensure
            mpccfg_io.close unless cfg.dryrun?
          end
        end

        def self.create_workspace(cfg)
          mwccfg = File.join(Configurator::ROOT, (cfg.options[:workspace] || MWCCFG)+'.mwc')
          # backup current file
          Util.backup_file(mwccfg) unless cfg.dryrun?
          # collect list of configured MWC project folders for enabled modules
          mwcinc = cfg.cfglist.values.collect do |mod|
            mod.mwc_include.inject([]) do |arr, (feature_id, inc)|
              arr.concat(inc) if cfg.cfglist.has_key?(feature_id) || (cfg.features.has_key?(feature_id) && cfg.features[feature_id].state)
              arr
            end
          end.flatten
          # generate mpc config file
          BRIX11.show_msg("Creating #{mwccfg}")
          begin
            mwccfg_io = cfg.dryrun? ? STDOUT : File.new(mwccfg, 'wb')
            mwccfg_io.puts("//----- #{MWCCFG} -----") if cfg.dryrun?
            mwccfg_io.puts('workspace {')
            mwcinc.each {|p| mwccfg_io.puts("  #{p}") }
            mwccfg_io.puts('}')
          ensure
            mwccfg_io.close unless cfg.dryrun?
          end
        end

      end

    end

  end

end
