#--------------------------------------------------------------------
# @file    base.rb
# @author  Martin Corino
#
# @brief   Base module for scaffolding tool brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
#--------------------------------------------------------------------
require 'optparse'
require 'json'
require 'brix11/log'
require 'brix11/project'

module BRIX11

  BRIX11_ROOT = File.dirname(__FILE__)

  class << self
    include LogMethods

    def options
      BRIX11::OPTIONS
    end

    def reporter
      @reporter ||= BRIX11::Reporter.new
    end

    def set_reporter(rep)
      @reporter = rep
    end

    private
    #
    # Configuration handling
    #
    def loaded_brix_paths
      @loaded_brix_paths ||= []
    end

  end

  def self.use_environment?
    options.config.use_environment
  end

  def self.dryrun?
    options.dryrun || false
  end

  def self.force?
    options.force || false
  end

  def self.interactive?
    options.interactive || false
  end

  Console::Text.label_format=('%-18s')
  Console::Text.indent = 1

  def self.console
    BRIX11::Console
  end

  #
  # Brix loading/handling
  #
  def self.load_brix
    log(2, 'Loading brix collections')
    # standard brix collection included in base
    unless Collection.loaded?('common') || !File.directory?(File.join(BRIX11_ROOT, 'brix', 'common'))
      bc = Collection.load(File.join(BRIX11_ROOT, 'brix', 'common'))
      bc.setup(options.optparser, options)
    end
    # configured brix collection search paths
    options.config.brix_paths.each do |brixpath|
      # expand env vars if present (could be if added through command line)
      brixpath.gsub!(/\$([^\s\/]+)/) { |m| ENV[$1] }
      log_fatal("Cannot access Brix search path #{brixpath}") unless File.directory?(brixpath)
      # make sure this is an absolute path
      brixpath = File.expand_path(brixpath)
      unless loaded_brix_paths.include?(brixpath)
        log(3, "Examining brix search path : #{brixpath}")
        Dir.glob(File.join(brixpath, 'brix', '*')).select {|p| File.directory?(p) }.each do |brixdir|
          log(4, "#load_brix - inspecting possible Brix collection @ #{brixdir}")
          if File.file?(File.join(brixdir, 'require.rb'))
            bc = Collection.load(brixdir)
            bc.setup(options.optparser, options)
          else
            log_warning("#load_brix - no loader module (require.rb) found @ #{brixdir}")
          end
        end
        loaded_brix_paths << brixpath
      end
    end
  end

  #
  # Argument parsing/handling
  #
  def self.init_optparser
    script_name = File.basename($0)
    if not script_name =~ /brix11/
      script_name = 'ruby '+$0
    end
    options.script_name = script_name

    # set up option parser with common options
    options.optparser = opts = OptionParser.new
    opts.banner = "Usage: #{script_name} [general options] command [options] [command [options] [...]\n"
    opts.separator "\n--- [General options] ---\n\n"

    opts.on('-I', '--include', '=PATH',
            'Adds search path for Brix collections.',
            "Default: loaded from ~/#{BRIX11RC} and/or ./#{BRIX11RC}") { |v|
      (options.user_config.brix_paths ||= []) << v.to_s
    }
    opts.on('-t', '--type', '=TYPE[:COMPILER]',
            'Defines project type used with optional compiler selection.',
            'Use --show-types to list available project types and active default.') { |v|
      val = v.to_s.split(':')
      options.user_config.project_type = val.shift
      options.user_config.project_compiler = val.shift unless val.empty?
    }
    opts.on('--show-types',
             'List available project types (with compiler options) and active default') {
      options.load_config
      load_brix
      puts "BRIX11 pluggable scaffolding tool #{VERSION_MAJOR}.#{VERSION_MINOR}.#{VERSION_RELEASE}"
      puts COPYRIGHT
      puts
      puts '  %-45s | %-35s' % ['Project type [compilers]','Description']
      puts '  '+('-' * 83)
      Project.describe_each do |type, compilers, desc|
        type_s = type.to_s
        type_s += ' (*)' if type_s == options.config.project_type
        type_s += ' [' unless compilers.empty?
        begin
          while (!compilers.empty?) && ((type_s.size + compilers.first.size) < 45)
            type_s += compilers.shift
            type_s += (compilers.empty? ? ']' : ',')
          end
          puts '  %-45s | %-40s' % [type_s, desc]
          type_s = '    '
          desc = ''
        end while !compilers.empty?
      end
      puts "#{' '*18} (*) = default"
      puts
    }
    opts.on('--add-templates', '=PATH',
            'Add a template library basepath to be evaluated before standard brix templates.') {|v|
      (options.user_config.user_templates ||= []) << v
    }
    opts.on('-E', '--environment',
            'Environment settings overrule BRIX11 (like RIDL_ROOT, ACE_ROOT, TAOX11_BASE_ROOT etc.).',
            "Default: #{options.config.use_environment ? 'on' : 'off'}") {
      options.user_config.use_environment = true
    }
    opts.on('-D', '--define', '=VARIABLE',
            'Define an additional environment variable for BRIX11 commands.',
            'Separate (optional) value by \'=\' like VAR=VAL. By default value will be \'1\'.',
            'Supports \$VAR and \${VAR}-form variable expansion.') { |v|
      _var, _val = v.split('=')
      (options.user_config.user_environment ||= {})[_var] = _val || '1'
    }
    opts.on('-x', '--crossbuild',
            'Define crossbuild configuration for BRIX11 commands.',
            'Requires definition of X11_HOST_ROOT and X11_TARGET_ROOT environment variables.') {
      options.user_config.crossbuild = true
    }

    opts.separator ''
    opts.on('-c', '--config', '=BRIX11RC',
            'Load config from BRIX11RC file.',
            "Default:  ~/#{BRIX11RC} and/or ./#{BRIX11RC}") { |v|
      options.add_config(v)
    }
    opts.on('--write-config', '=[BRIX11RC]',
            'Write config to file and exit.',
            "Default: ./#{BRIX11RC}") { |v|
      options.save_user_config(String === v ? v : BRIX11RC)
      exit
    }
    opts.on('--show-config', '=[BRIX11RC]',
            'Print specified or active config and exit.',
            "Default: active configuration") { |v|
      options.load_config unless String === v
      puts "BRIX11 pluggable scaffolding tool #{VERSION_MAJOR}.#{VERSION_MINOR}.#{VERSION_RELEASE}"
      puts COPYRIGHT
      puts
      puts options.print_config(String === v ? v : nil)
      exit
    }

    opts.separator ''
    opts.on('-l', '--list-collections',
            'List available brix collections and exit.') {
      options.load_config
      load_brix
      puts "BRIX11 pluggable scaffolding tool #{VERSION_MAJOR}.#{VERSION_MINOR}.#{VERSION_RELEASE}"
      puts COPYRIGHT
      puts
      print '  '
      puts Collection.descriptions.join("\n  ")
      puts
      exit
    }
    opts.on('-L', '--list', '=[all]',
            'List available brix (for selected collection) and exit.',
            'Also list collections of overridden entries if \'all\' specified.') { |v|
      BRIX11.log_fatal("Invalid switch -L#{v}") unless v == true || v=='all'
      options.load_config
      load_brix
      puts "BRIX11 pluggable scaffolding tool #{VERSION_MAJOR}.#{VERSION_MINOR}.#{VERSION_RELEASE}"
      puts COPYRIGHT
      puts
      print '  '
      puts Command.descriptions(options.scope, !v.nil?).join("\n  ")
      puts
      puts %Q{  '*' marks command entries that override (possibly extending) identically named commands in other collections.}
      puts %Q{  Use '-Lall' to show the names of overridden collections in this list.'}
      puts %Q{  Use '--scope=' to exclusively list or execute commands from the specified collection.}
      puts
      exit
    }
    opts.on('--scope', '=COLLECTION',
            'Defines collection scope for filtering commands.',
            'Default: no scope') {|v|
      options.scope = v
    }

    opts.separator ''
    opts.on('-V', '--version',
            'Show version information and exit.') {
      puts "BRIX11 pluggable scaffolding tool #{VERSION_MAJOR}.#{VERSION_MINOR}.#{VERSION_RELEASE}"
      puts COPYRIGHT
      puts
      puts '--- [Brix collections] ---'
      Collection.print_versions
      puts
      exit
    }

    # TODO : is this useful?
    #opts.on_tail('--[no-]interact',
    #             '(Do not) run commands interactively.',
    #             'Default: interactive') { |v| options.interactive = v }
    opts.on_tail('-f', '--force',
                 'Force all tasks to run even if their dependencies do not require them to.',
                 'Default: off') { options.force = true }
    opts.on_tail('-n', '--dryrun',
                 'Perform dry run (no destructive/persistent actions).',
                 'Default: off') {
                      options.dryrun = true
                    }
    opts.on_tail('-v', '--verbose',
                 'Run with increased verbosity level. Repeat to increase more.',
                 'Default: 1') { options.verbose += 1 }
    opts.on_tail('-q', '--quiet',
                 'Run silent (verbosity 0).',
                 'Default: 1') { options.verbose = 0 }
    opts.on_tail('-C', '--capture', '=FILENAME',
                 'Capture command output to file FILENAME.',
                 'Default:  do not capture output.') { |v|
                      begin
                        options.logfile = File.open(v.to_s, 'w')
                        BRIX11.reporter.output = Formatter::Tee.new(options.logfile)
                      rescue Exception => ex
                        BRIX11.log_fatal("Failed to open logfile [#{v}]: #{ex}")
                      end
                    }

    opts.separator ''
    opts.on_tail('-h', '--help',
                 'Show this help message.',
                 "Use '#{script_name} command -h' to show command (option specific) help.") {
                   options.help_proc.call
                 }
    opts
  end

  def self.run(argv = ARGV)
    opts = init_optparser

    # handle arguments
    if argv.empty?
      options.help_proc.call
    end

    rc = true
    begin
      opts.order!(argv)

      # load config (if any)
      options.load_config

      # load Brix collections
      load_brix

      until argv.empty? || !rc
        rc = execute(argv)
      end
    rescue
      verbosity>1 ? log_fatal("#{$!}\n#{$!.backtrace.join("\n")}") : log_fatal("#{$!}\n(run with '-v' to see more information)\n")
    ensure
      options.logfile.close if options.logfile
    end
  end

  def self.execute(argv)
    rc = nil
    begin
      rc = Command.parse_args(argv, options.dup)
    rescue Command::CmdError => exe
      log_error(exe.message)
      rc = false
    end
    rc
  end

end # BRIX11
#Need to require this files AFTER the base is setup
require 'brix11/options'
require 'brix11/system'
require 'brix11/console'
require 'brix11/collection'
