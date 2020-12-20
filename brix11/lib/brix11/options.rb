#--------------------------------------------------------------------
# @file    options.rb
# @author  Martin Corino
#
# @brief   Options module for scaffolding tool brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'ostruct'
require 'brix11/log'

module BRIX11

  BRIX11RC = '.brix11rc'
  BRIX11RC_GLOBAL = File.expand_path(File.join(ENV['HOME'] || ENV['HOMEPATH'] || '~', BRIX11RC))

  OPTIONS = OpenStruct.new

  class << OPTIONS

    include BRIX11::LogMethods

    def options
      self
    end

    class Config < OpenStruct

      include BRIX11::LogMethods

      def self.merge(to, from)
        from.each_pair do |(k,v)|
          k = k.to_sym
          if to.has_key?(k)
            case to[k]
            when Array
              to[k].concat v
            when Hash
              to[k].merge!(v)
            when OpenStruct
              _merge(to[k], v)
            else
              to[k] = v
            end
          else
            to[k] = v
          end
        end
        to
      end

      def initialize(hash=nil)
        super(Config.merge(_defaults, hash || {}))
      end

      def options
        BRIX11.options
      end

      def merge(from)
        Config.merge(self, from)
        self
      end

      def has_key?(k)
        @table.has_key?(k)
      end

      def load(rcpath)
        log(3, "Loading #{BRIX11RC} from #{rcpath}")
        begin
          _cfg = JSON.parse(IO.read(rcpath))
        rescue JSON::ParserError => ex
          log_fatal("Error parsing JSON file #{rcpath}: #{ex}")
        end
        log(4, "Read from #{rcpath}: [#{_cfg}]")
        _rcdir = File.dirname(rcpath)
        # handle automatic env var expansion in brix_paths
        _cfg['brix_paths'] = (_cfg['brix_paths'] || []).collect do |p|
          log(5, "Examining brix_path [#{p}]")
          # for paths coming from rc files environment vars are immediately expanded and
          p.gsub!(/\$([^\s\/]+)/) { |m| ENV[$1] }
          log(6, "Expanded brix_path [#{p}]")
          # resulting relative paths converted to absolute paths
          _fp = File.expand_path(p, _rcdir)
          if File.directory?(_fp) # relative to rc location?
            p = _fp
          end # or relative to working dir
          log_fatal("Cannot access Brix search path #{p} configured in #{rcpath}") unless File.directory?(p)
          log(4, "Adding brix collection search path : #{p}")
          p
        end
        merge(_cfg)
      end

      def save(rcpath)
        File.open(rcpath, 'w') {|f| f << JSON.pretty_generate(@table) }
      end

      def to_s
        JSON.pretty_generate(@table)
      end

      protected

      def _defaults
        {
          :brix_paths => []
        }
      end

    end

    protected

    def _defaults
      {
        :verbose => (ENV['BRIX11_VERBOSE'] || 1).to_i,
        :help_proc => lambda {
          options.load_config
          load_brix
          puts "BRIX11 pluggable scaffolding tool #{VERSION_MAJOR}.#{VERSION_MINOR}.#{VERSION_RELEASE}"
          puts COPYRIGHT
          puts
          puts BRIX11.options.optparser
          puts
          exit
        },
        :config => Config.new({
          :project_type => 'gnuace',
          :use_environment => false
        })
      }
    end

    def _rc_paths
      @rc_paths ||= []
    end
    def _loaded_rc_paths
      @loaded_rc_paths ||= []
    end

    def _add_rcpath(path)
      if _loaded_rc_paths.include?(File.expand_path(path))
        log(3, "ignoring already loaded rc : #{path}")
      else
        log(3, "adding rc path : #{path}")
        _rc_paths << path
      end
      _rc_paths
    end

    public

    def has_key?(k)
      @table.has_key?(k)
    end

    def reset
      @table.clear
      Config.merge(self, _defaults)
      #update_to_values!(_defaults)
      _rc_paths.clear
      _rc_paths << BRIX11RC_GLOBAL
      _loaded_rc_paths.clear
      (ENV['BRIX11RC'] || '').split(/:|;/).each do |p|
        _add_rcpath(p)
      end
    end

    def load_config
      # first collect config from known (standard and configured) locations
      _rc_paths.collect {|path| File.expand_path(path) }.each do |rcp|
        log(3, "Testing rc path #{rcp}")
        if File.readable?(rcp) && !_loaded_rc_paths.include?(rcp)
          _cfg = Config.new.load(rcp)
          self[:config].merge(_cfg)
          _loaded_rc_paths << rcp
        else
          log(3, "Ignoring #{File.readable?(rcp) ? 'already loaded' : 'inaccessible'} rc path #{rcp}")
        end
      end
      # now scan working path for any rc files unless specified otherwise
      unless self[:no_rc_scan]
        _cwd = File.expand_path(Dir.getwd)
        log(3, "scanning working path #{_cwd} for rc files")
        # first collect any rc files found
        _rcpaths = []
        begin
          _rcp = File.join(_cwd, BRIX11RC)
          if File.readable?(_rcp) && !_loaded_rc_paths.include?(_rcp)
            _rcpaths << _rcp
          else
            log(3, "Ignoring #{File.readable?(_rcp) ? 'already loaded' : 'inaccessible'} rc path #{_rcp}")
          end
          break if /\A(.:(\\|\/)|\.|\/)\Z/ =~ _cwd
          _cwd = File.dirname(_cwd)
        end while true
        # now load them in reverse order
        _rcpaths.reverse.each do |_rcp|
          _cfg = Config.new.load(_rcp)
          self[:config].merge(_cfg)
          _loaded_rc_paths << _rcp
        end
      end
      # lastly merge config specified by user on commandline
      self[:config].merge(user_config)
    end

    def add_config(rcpath)
      log_fatal("inaccessible rc path specified : #{rcpath}") unless File.readable?(rcpath)
      _add_rcpath(rcpath)
    end

    def user_config
      @user_config ||= Config.new
    end

    def save_user_config(rcpath)
      _cfg = Config.new
      _cfg.load(rcpath) if File.readable?(rcpath)
      _cfg.merge(user_config)
      _cfg.save(rcpath)
    end

    def print_config(rcpath = nil)
      cfg = if rcpath
              if File.readable?(rcpath)
                _cfg = Config.new
                _cfg.load(rcpath)
                _cfg.merge(user_config)
              else
                "WARNING: Cannot access file #{rcpath}"
              end
            else
              self[:config].merge(user_config)
            end
      cfg.to_s
    end

  end # OPTIONS class

  OPTIONS.reset # initialize

end # BRIX11
