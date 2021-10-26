#--------------------------------------------------------------------
# @file    system.rb
# @author  Martin Corino
#
# @brief   System support for scaffolding tool brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'fileutils'

module BRIX11

  module Sys

    def self.mswin?
      /mingw/ =~ RUBY_PLATFORM ? true : false
    end

    def self.has_ansi?
      # only ANSI escape code support on Windows
      # if ANSICON (https://github.com/adoxa/ansicon) installed
      (!mswin?) || ENV['ANSICON']
    end

    def self.get_cpu_cores
      unless @cpu_cores
        if mswin?
          @cpu_cores = (ENV['NUMBER_OF_PROCESSORS'] || 1).to_i
        else
          @cpu_cores = (`cat /proc/cpuinfo | grep processor | wc -l` rescue '1').strip.to_i
        end
      end
      @cpu_cores
    end

    def self.get_max_cpu_cores
      unless @max_cpu_cores
        max_cpu = (BRIX11::Exec.get_run_environment('BRIX11_NUMBER_OF_PROCESSORS', true) || 0).to_i
        @max_cpu_cores =  [max_cpu, get_cpu_cores].min
      end
      @max_cpu_cores
    end

    def self.expand(cmd, default='', redirect_err=true)
      excmd = cmd
      if redirect_err
        excmd << ' 2>' << (mswin? ? 'NUL' : '/dev/null')
      else
        excmd << ' 2>&1'
      end
      %x{#{excmd}} rescue default
    end

    def self.pager
      if mswin?
        'more'
      else
        # check for 'less'
        if expand('which less').strip.empty?
          # 'more'?
          if expand('which more').strip.empty?
            'cat'
          else
            'more'
          end
        else
          'less'
        end
      end
    end

    def self.environment_command(env, val)
      if mswin?
        %Q{set #{env}=#{val}}
      else
        %Q{export #{env}=#{val}}
      end
    end

    def self.tempdir
      mswin? ? (ENV['TEMP'] || '.') : (ENV['TMPDIR'] || '/tmp')
    end

    def self.compare_path(path1, path2)
      mswin? ? path1.casecmp(path2) : (path1 <=> path2)
    end

    def self.in_dir(dir, &block)
      BRIX11.log(3, 'cd %s', dir)
      rc = if BRIX11.dryrun?
        yield if block_given?
      else
        Dir.chdir(dir, &block)
      end
      BRIX11.log(3, 'cd -')
      rc
    end

    def self.mkdir(path)
      FileUtils.makedirs(path, :verbose => BRIX11.verbose?, :noop => BRIX11.dryrun?) rescue nil
      BRIX11.dryrun? ? true : File.directory?(path)
    end

    def self.mv(src, tgt)
      FileUtils.move(src, tgt, :verbose => BRIX11.verbose?, :noop => BRIX11.dryrun?)
    end

    def self.cp(src, tgt)
      FileUtils.copy(src, tgt, :verbose => BRIX11.verbose?, :noop => BRIX11.dryrun?)
    end

    def self.chmod(mode, path)
      FileUtils.chmod(mode, path, :verbose => BRIX11.verbose?, :noop => BRIX11.dryrun?)
    end

    def self.rm(path)
      FileUtils.rm(path, :verbose => BRIX11.verbose?, :noop => BRIX11.dryrun?)
    end

  end

  include Sys

end
