#--------------------------------------------------------------------
# @file    collection.rb
# @author  Martin Corino
#
# @brief   BRIX11 command collection definitions
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/command'

module BRIX11
  class Collection

    BASEDIR = 'brix'

    class << self
    private
      def collections
        @collections ||= {}
      end
    end

    class Configurator
      attr_reader :collection
      def initialize(name, root, title, description, copyright, version)
        @collection = BRIX11::Collection.new(name, root, title, description, copyright, version)
        @bc_ext_klass = class << @collection; self; end
      end

      def add_collection(name)
        @collection.instance_variable_get('@base_collections') << BRIX11::Collection.find(name)
      end

      def add_optional_collection(name)
        if oc = BRIX11::Collection.find(name, false)
          @collection.instance_variable_get('@base_collections') << oc
        end
      end

      def on_setup(&block)
        @bc_ext_klass.send(:define_method, :_setup_bc, &block)
        @bc_ext_klass.send(:private, :_setup_bc)
      end
    end

    # search for collection in brix search paths
    # attempt to load first match found
    def self.find(name, required = true)
      # iterate configured brix collection search paths
      BRIX11.options.config.brix_paths.each do |brixpath|
        # expand env vars if present (could be if added through command line)
        brixpath.gsub!(/\$([^\s\/]+)/) { |m| ENV[$1] }
        BRIX11.log_fatal("Cannot access Brix search path #{brixpath}") unless File.directory?(brixpath)
        # make sure this is an absolute path
        brixpath = File.expand_path(brixpath)
        # extend to full potential collection path
        brixpath = File.join(brixpath, 'brix', name.to_s)
        if File.directory?(brixpath)
          BRIX11.log(3, "Examining brix collection path : #{brixpath}")
          if File.file?(File.join(brixpath, 'require.rb'))
            bc = Collection.load(brixpath)  # handles recursive loading
            bc.setup(BRIX11.options.optparser, BRIX11.options) # only actually executes setup once
            return bc
          else
            BRIX11.log_warning("Collection#find - no loader module (require.rb) found @ #{brixpath}")
          end
        end
      end
      BRIX11.log_fatal("Unable to find required collection #{name}") if required
      nil
    end

    # path should be either a relative path like 'brix/<name>' or
    # a full path like /path/to/brix/<name> (in which case the path
    # to the brix folder is added to the library search path)
    def self.load(path)
      name = File.basename(path).to_sym                  # collection name
      if loaded?(name)
        if Sys.compare_path(collections[name.to_sym].root, path) != 0
          BRIX11.log_fatal("Duplicate Brix collection [:#{name}] @ #{path} (previously loaded from #{collections[name].root})")
        end
        # silently ignore multiple loading attempts for the same collection
        BRIX11.log(2, "> returning already loaded BRIX11 collection :#{name} from #{collections[name].root}")
        return collections[name]
      end
      libpath = File.dirname(path)
      BRIX11.log_fatal("Invalid Brix collection path #{path}") unless File.basename(libpath) == BASEDIR
      if libpath =~ /^(\/|.:)/                    # absolute path
        libpath = File.dirname(libpath)           # lib path
        $: << libpath unless $:.include?(libpath) # add to library search path if not yet done
      end
      _c = Command.get_collection    # cache current collection
      Command.set_collection(name)   # set command loading scope
      begin
        # load mapping from standard extension dir in Ruby search path
        require "brix/#{name}/require"
        BRIX11.log_fatal("BRIX11 collection :#{name} did not register correctly") unless collections.has_key?(name)
        BRIX11.log(2, "> loaded BRIX11 collection :#{name} from #{collections[name].root}")
        # return backend
        return collections[name]
      rescue LoadError => ex
        BRIX11.log_error "Cannot load BRIX11 collection [:#{name}] @ #{path}"
        BRIX11.log_error ex.inspect
        BRIX11.log_error(ex.backtrace.join("\n")) if $VERBOSE
        exit 1
      ensure
        Command.set_collection(_c)   # reset command loading scope
      end
    end

    def self.loaded?(name)
      collections.has_key?(name.to_sym)
    end

    def self.[](name)
      collections[name.to_sym]
    end

    def self.print_versions
      collections.values.each { |c| c.print_version }
    end

    def self.descriptions
      maxlen = collections.keys.collect { |cn| cn.to_s.size }.max
      maxlen = ((maxlen / 5) * 5) + 10
      desc = ["%-#{maxlen}s | %s" % ['Collection', 'Description']]
      desc << ('-'*(maxlen+43))
      collections.values.sort { |a,b| a.name.to_s <=> b.name.to_s }.each do |bc|
        desc << "%-#{maxlen}s | %s" % [bc.name, bc.description]
      end
      desc
    end

    def self.configure(name, root, title, description, copyright, version, &block)
      cfg = Configurator.new(name, root, title, description, copyright, version)
      block.call(cfg)
      collections[cfg.collection.name] = cfg.collection
    end

    def self.lookup_path
      collections.values.collect { |c| c.lookup_path }.flatten
    end

    def initialize(name, root, ttl, desc, cpr, ver)
      @name = name.to_sym
      @root = root
      @title = ttl
      @description = desc
      @copyright = cpr
      @version = (Hash === ver ? ver : { major: ver.to_i, minor: 0, release: 0 })
      @base_collections = []
      @setup_done = false
    end

    attr_reader :name, :root, :title, :description, :copyright

    def version
      "#{@version[:major]}.#{@version[:minor]}.#{@version[:release]}"
    end

    def print_version
      puts "#{title} #{version}"
      puts copyright
      #@base_collections.each {|be| puts '---'; be.print_version }
    end

    def lookup_path
      @base_collections.inject([@root]) { |paths, bbc| paths.concat(bbc.lookup_path) }
    end

    def setup(optparser, options)
      # only run setup once
      return if @setup_done
      # initialize base collections in reverse order so each dependent BC can overrule its
      # base settings
      @base_collections.reverse.each do |bc|
        _c = Command.get_collection
        begin
          Command.set_collection(bc.name)
          bc.setup(optparser, options)
        ensure
          Command.set_collection(_c)
        end
      end
      _c = Command.get_collection
      begin
        Command.set_collection(name)
        # initialize this collection
        _setup_bc(optparser, options)
        @setup_done = true
      ensure
        Command.set_collection(_c)
      end
    end

  end
end
