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
          if Exec.get_run_environment('TAOX11_ROOT')
            mpccfg = File.join(Exec.get_run_environment('TAOX11_ROOT'), 'bin', 'MPC', 'config', MPCCFG)
          else
            mpccfg = File.join(Configurator::ROOT, 'taox11', 'bin', 'MPC', 'config', MPCCFG)
          end
          # backup current file
          Util.backup_file(mpccfg) unless cfg.dryrun?
          # collect list of configured MPC include folders for enabled modules
          mpcinc = cfg.rclist.values.collect do |rc|
            rc.mpc_include
          end.flatten
          # generate mpc config file
          BRIX11.show_msg("Creating #{mpccfg}")
          begin
            mpccfg_io = cfg.dryrun? ? STDOUT : File.new(mpccfg, 'w')
            mpccfg_io.puts("//----- #{MPCCFG} -----") if cfg.dryrun?
            mpccfg_io.puts("includes = #{mpcinc.join(', ')}")
            mpccfg_io.puts('dynamic_types = $MPC_ROOT, $TAO_ROOT/MPC, $TAOX11_ROOT/bin/MPC')
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
          mwcinc = cfg.rclist.values.collect do |rc|
            rc.mwc_include.inject([]) do |arr, (feature_id, inc)|
              arr.concat(inc) if cfg.rclist.has_key?(feature_id) || (cfg.features.has_key?(feature_id) && cfg.features[feature_id].state)
              arr
            end
          end.flatten
          # generate mpc config file
          BRIX11.show_msg("Creating #{mwccfg}")
          begin
            mwccfg_io = cfg.dryrun? ? STDOUT : File.new(mwccfg, 'w')
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
