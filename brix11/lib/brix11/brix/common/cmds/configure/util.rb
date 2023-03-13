#--------------------------------------------------------------------
# @file    util.rb
# @author  Martin Corino
#
# @brief  Configure tool utility methods
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'pathname'
require 'time'

module BRIX11
  module Common
    class Configure  < Command::Base

      module Util
        class << self

          def backup_file(fpath)
            # do we have anything to backup?
            if File.exist?(fpath)
              # Define the backup filename with current date/time as file extension
              backup_file = fpath + '.' + Time.now.strftime('%Y%m%d%H%M%S')
              # remove any existing backup file
              File.delete(backup_file) if File.exist?(backup_file)
              # rename file to backup
              File.rename(fpath, backup_file)
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
