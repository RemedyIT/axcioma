#--------------------------------------------------------------------
# @file    require.rb
# @author  Martin Corino
#
# @brief   BRIX11 Common brix collection loader
#
# @copyright Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
#--------------------------------------------------------------------

module BRIX11

  module Common

    ROOT = File.dirname(__FILE__)
    TITLE = 'Common'.freeze
    DESC = 'BRIX11 Common brix collection'.freeze
    COPYRIGHT = "Copyright (c) 2014-#{Time.now.year} Remedy IT Expertise BV, The Netherlands".freeze
    VERSION = {major: 0, minor: 1, release: 0}

    Collection.configure(:common, ROOT, TITLE, DESC, COPYRIGHT, VERSION) do |cfg|

      cfg.on_setup do |optparser, options|
        # define common environment for spawning BRIX11 subprocesses
        env = {}
        ridl_root = Exec.get_run_environment('RIDL_ROOT')
        ridl_root ||= if File.file?(File.join(BRIX11_BASE_ROOT, 'ridl', 'ridl.rb'))
                        Exec.update_run_environment('RIDL_ROOT', BRIX11_BASE_ROOT)
                      else
                        base_root = File.dirname(BRIX11_BASE_ROOT)
                        if File.directory?(File.join(base_root, 'ridl', 'lib'))
                          Exec.update_run_environment 'RIDL_ROOT', File.join(base_root, 'ridl', 'lib')
                        else
                          ''
                        end
                      end
        $: << ridl_root if ridl_root && !$:.include?(ridl_root)
        mpc_root = Exec.get_run_environment('MPC_ROOT')
        unless mpc_root
          # try to find an MPC installation somewhere from BRIX11_BASE_ROOT down
          root = BRIX11_BASE_ROOT
          until root =~ /^(\/|.:[\/\\])$/
            root = File.dirname(root)
            if File.directory?(File.join(root, 'MPC')) && File.file?(File.join(root, 'MPC', 'mwc.pl'))
              mpc_root = File.join(root, 'MPC')
              break
            elsif File.directory?(File.join(root, 'ACE', 'MPC')) && File.file?(File.join(root, 'MPC', 'ACE', 'mwc.pl'))
              mpc_root = File.join(root, 'ACE', 'MPC')
              break
            end
          end
          Exec.update_run_environment('MPC_ROOT', mpc_root) if mpc_root
        end
        Project.mpc_path = mpc_root if mpc_root
      end

    end

    Dir.glob(File.join(ROOT, 'cmds', '*.rb')).each { |p| require "brix/common/cmds/#{File.basename(p)}"}

  end

end
