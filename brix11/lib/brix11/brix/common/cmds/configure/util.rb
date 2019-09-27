#--------------------------------------------------------------------
# @file    util.rb
# @author  Martin Corino
#
# @brief  Configure tool utility methods
#
# @copyright Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
#--------------------------------------------------------------------

require 'pathname'

module BRIX11

  module Common

    class Configure  < Command::Base

      module Util

        class << self

          def backup_file(fpath)
            # do we have anything to backup?
            if File.exist?(fpath)
              # remove any existing backup file
              File.delete(fpath+'.org') if File.exist?(fpath+'.org')
              # rename file to backup
              File.rename(fpath, fpath+'.org')
              true
            else
              false
            end
          end

          def revert_file(fpath)
            # check if backup exists
            if File.exist?(fpath+'.org')
              # remove file if exists
              File.delete(fpath) if File.exist?(fpath)
              # rename backup
              File.rename(fpath+'.org', fpath)
              true
            else
              false
            end
          end

          def relative_path(path, relbase)
            p = Pathname.new(path)
            p.relative_path_from(Pathname.new(relbase)).to_s
          end

        end

      end

    end

  end

end
