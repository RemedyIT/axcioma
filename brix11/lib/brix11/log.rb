#--------------------------------------------------------------------
# @file    log.rb
# @author  Martin Corino
#
# @brief   BRIX11 logging support
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/formatter'

module BRIX11
  #
  # Reporting/Logging
  #
  class Reporter
    def output
      @output ||= Console
    end

    def output=(out)
      @output = out
    end

    include Screen::ColorizeMethods

    def log_fatal(msg, rc = 1)
      output.error_println 'BRIX11 - ',red(bold 'ERROR'), ' : ', msg
      exit rc
    end

    def log_error(msg)
      output.error_println 'BRIX11 - ', red(bold 'ERROR'), ' : ', msg
    end

    def log_warning(msg)
      output.error_println 'BRIX11 - ', yellow(bold 'WARNING'), ' : ', msg
    end

    def log_information(msg)
      output.error_println 'BRIX11 - ', bold('INFO'), ' : ', msg
    end

    def log(msg, *args)
      Console.println 'BRIX11 - ', (msg % args)
    end

    def print(*args)
      Console.print(*args)
    end

    def println(*args)
      Console.println(*args)
    end

    def show_error(msg)
      log_error(msg)
    end

    def show_warning(msg)
      log_error(msg)
    end

    def show_msg(msg)
      log(msg)
    end
  end

  module LogMethods
    def log_fatal(msg, rc = 1)
      BRIX11.reporter.log_fatal(msg, rc)
    end

    def log_error(msg)
      BRIX11.reporter.log_error(msg)
    end

    def log_warning(msg)
      BRIX11.reporter.log_warning(msg)
    end

    def log_information(msg)
      BRIX11.reporter.log_information(msg)
    end

    def log(lvl, msg, *args)
      BRIX11.reporter.log(msg, *args) if lvl <= verbosity
    end

    def print(*args)
      BRIX11.reporter.print(*args)
    end

    def println(*args)
      BRIX11.reporter.println(*args)
    end

    def show_error(msg)
      BRIX11.reporter.show_error(msg)
    end

    def show_warning(msg)
      BRIX11.reporter.show_warning(msg)
    end

    def show_msg(msg)
      BRIX11.reporter.show_msg(msg)
    end

    def verbosity
      (options[:verbose] || 0).to_i
    end

    def verbose?
      verbosity > 1
    end

    def silent?
      verbosity < 1
    end
  end
end # BRIX11
