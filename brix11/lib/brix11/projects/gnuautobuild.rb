#--------------------------------------------------------------------
# @file    gnuautobuild.rb
# @author  Martin Corino
#
# @brief   MPC 'gnuace' project type support for brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/projects/gnuace'

module BRIX11
  module Project
    class GnuAutobuild < GnuAce
      ID = 'gnuautobuild'
      DESCRIPTION = 'GNU Make makefiles for use with parallel make'

      protected

      def base_build_arg(project, path, cmdargv, opts)
        argv = super
        (argv << '-j' << (Exec.max_cpu_cores > 0 ? Exec.max_cpu_cores : Exec.cpu_cores)) if Exec.cpu_cores > 1
        argv
      end
    end # Handler

    register(GnuAutobuild::ID, GnuAutobuild)
  end # Project
end # BRIX11
