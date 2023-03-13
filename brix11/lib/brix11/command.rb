#--------------------------------------------------------------------
# @file    command.rb
# @author  Martin Corino
#
# @brief   BRIX11 Command loader/registry and mixin
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'optparse'
require 'brix11/project'
require 'brix11/process'

module BRIX11
  module Command
    Entry = Struct.new(:id, :aliases, :scoped_id, :desc, :klass, :collection, :super, :override)

    AliasEntry = Struct.new(:id, :table) do
      def entry
        table[id]
      end

      def aliases
        entry.aliases
      end

      def scoped_id
        entry.scoped_id
      end

      def desc
        entry.desc
      end

      def klass
        entry.klass
      end

      def collection
        entry.collection
      end

      def super
        entry.super
      end

      def override
        entry.override
      end
    end

    Node = Struct.new(:id, :aliases, :table)

    AliasNode = Struct.new(:node) do
      def table
        node.table
      end
    end

    MIN_CMDLEN = 3

    self.singleton_class.class_eval do
    private
      def commands
        @cmds ||= {}
      end

      def scoped_commands
        @scoped_cmds ||= {}
      end

      def cur_collection_scope
        @cur_scope
      end

      def set_cur_collection(scope)
        @cur_scope = scope
      end

      def get_overridden_collections(obj)
        [obj.collection].concat(obj.super ? get_overridden_collections(obj.super) : [])
      end

      def determin_max_desc(container, all)
        container.collect do |id, obj|
          id.size + case obj
                    when Entry
                      obj.id.size +
                          obj.aliases.inject(0) { |a| a.size + 1 } +
                          if all && obj.super
                            get_overridden_collections(obj).join(',').size + 3
                          else
                            0
                          end
                    when Node
                      determin_max_desc(obj.table, all) + obj.aliases.inject(0) { |a| a.size + 1 }
                    else
                      0
                    end
        end.max
      end

      def collect_desc(container, maxlen, scope, path = [], all)
        descs = []
        pfx = path.empty? ? '' : (path.join(' ') << ' ')
        container.keys.sort.each do |id|
          case obj = container[id]
          when Entry
            collection_str = obj.collection.dup
            if all && obj.super
              collection_str << " [#{get_overridden_collections(obj).join(',')}]"
            end
            descs << "%-#{maxlen}s | %s" % ["#{pfx}#{([id] + obj.aliases).join('|')}#{obj.super ? '*' : ''} (#{collection_str})", obj.desc]
          when Node
            descs.concat collect_desc(obj.table, maxlen, nil, scope ? path : (path + [([id] + obj.aliases).join('|')]), all)
          end
        end
        descs
      end
    end

    def self.options
      BRIX11.options
    end

    def self.set_collection(scope = nil)
      set_cur_collection(scope ? scope.to_s : nil)
    end

    def self.get_collection
      cur_collection_scope
    end

    def self.register(cmdid, desc, klass, override = false)
      BRIX11.log(2, "Registering brix command #{cmdid}=#{desc} in collection #{cur_collection_scope}")
      idlist = cmdid.to_s.split(':').collect { |s| s.split('|') } # extract optional namespaces and aliases
      BRIX11.log_fatal("Namespace or command ids and aliases should be at least #{MIN_CMDLEN} long") if idlist.flatten.any? { |i| i.size < MIN_CMDLEN }
      scoped_ids = []
      ids = idlist.pop # actual cmd ids (first is primary id, rest aliases)
      # get root containers
      container = commands
      scoped_container = (scoped_commands[cur_collection_scope] ||= {})
      # descend down the namespaces
      until idlist.empty?
        # first namespace level
        nsids = idlist.shift
        # check for id clashes
        nsids.each { |nsnm| BRIX11.log_fatal("Brix command namespace id [#{nsnm}] clashes with existing command") if Entry === container[nsnm] }
        nsid = nsids.shift # first id is primary namespace id, rest aliases
        scoped_ids << nsid
        BRIX11.log_fatal("Brix command namespace [#{nsid}] clashes with existing namespace alias") if AliasNode === container[nsid]
        nsids.each { |nsnm| BRIX11.log_fatal("Brix command namespace alias [#{nsnm}] clashes with existing namespace") if Node === container[nsnm] }
        # update namespace nodes (and aliases)
        container[nsid] ||= Node.new(nsid, [], {})
        container[nsid].aliases = (container[nsid].aliases | nsids)
        nsids.each { |nsalias| container[nsalias] ||= AliasNode.new(container[nsid]) }
        container = container[nsid].table

        scoped_container[nsid] ||= Node.new(nsid, [], {})
        scoped_container[nsid].aliases = (scoped_container[nsid].aliases | nsids)
        nsids.each { |nsalias| scoped_container[nsalias] ||= AliasNode.new(scoped_container[nsid]) }
        scoped_container = scoped_container[nsid].table
      end
      scoped_ids << ids.first
      # create new command entry
      ce = Entry.new(ids.shift, ids.dup, scoped_ids.join(':'), desc, klass, cur_collection_scope)
      BRIX11.log_fatal("Brix command [#{ce.scoped_id}] clashes with existing namespace or an alias") unless container[ce.id].nil? || Entry === container[ce.id]
      ce.aliases.each { |ca| BRIX11.log_fatal("Brix command [#{ce.scoped_id}] alias [#{ca}] clashes with existing namespace(-alias) or command") unless container[ca].nil? || AliasEntry === container[ca] }
      if container.has_key?(ce.id)
        BRIX11.log_fatal("Duplicate Brix command [#{ce.scoped_id}] without override specified") unless override
        ce.super = container[ce.id]       # chain previous command entry
        container[ce.id].override = ce    # chain next command entry
      end
      container[ce.id] = ce
      ce.aliases.each { |ca| container[ca] ||= AliasEntry.new(ce.id, container) }
      BRIX11.log_fatal("Duplicate Brix command [#{ce.scoped_id}] in scope #{cur_collection_scope}") if scoped_container.has_key?(ce.id)
      scoped_container[ce.id] = ce
      ce.aliases.each { |ca| scoped_container[ca] ||= AliasEntry.new(ce.id, scoped_container) }
      ce
    end

    # tests if arg is (part of) command id
    def self.is_command_arg?(arg, options)
      # determin base container to select command from
      container = options[:scope] ? scoped_commands[options[:scope]] : commands
      # if compound id (with embedded ':') get first segment
      idstr = (arg || '').split(':').shift
      if idstr
        unless (object = container[idstr]) || idstr.size < MIN_CMDLEN
          # Check for partial match
          object = container.keys.select { |k| k.start_with?(idstr) }.shift
          object = container[object] if object
        end
        case object
        when Entry, Node, AliasEntry, AliasNode
          return true
        end
      end
      return false
    end

    def self.parse_command(argv, options)
      # determin base container to select command from
      container = options[:scope] ? scoped_commands[options[:scope]] : commands
      BRIX11.log_fatal("Unknown scope [#{options[:scope]}] for commands") unless container
      # parse specified command from argument list
      cmdspec = []
      # skip any superfluous noop switches
      until argv.empty? || argv.first != '--'
        argv.shift
      end
      first = true
      until argv.empty? || argv.first.start_with?('-')
        cmdspec << (arg = argv.shift)
        path = arg.split(':') # determin possible command path segments
        # walk the path
        object = nil
        until path.empty?
          idstr = path.shift
          object = container[idstr]
          unless object || idstr.size < MIN_CMDLEN
            # Check for partial match
            matches = container.keys.select { |k| k.start_with?(idstr) }
            if matches.size > 1
              BRIX11.log_error("Multiple commands or namespaces match [#{idstr}] : #{matches.join('|')}")
              return nil
            end
            object = container[matches.first] unless matches.empty?
          end
          unless object
            if first
              first = false
              # check if first name segment might be collection scope
              object = scoped_commands[idstr]
              unless object || idstr.size < MIN_CMDLEN
                # partial match ?
                matches = scoped_commands.keys.select { |k| k.start_with?(idstr) }
                # only if single match
                object = scoped_commands[matches.first] unless matches.size > 1
              end
            end
            unless object
              BRIX11.log_error("Unknown command id or namespace [#{idstr}]")
              return nil
            end
          end
          if Entry === object || AliasEntry === object
            # did we find a command at the end of the path as expected?
            return object if path.empty?
            BRIX11.log_fatal("Unknown command [#{arg}]")
            return nil
          else
            container = Hash === object ? object : object.table
          end
          # next path segment if any
        end
        # if we get here we need to find a next namespace/command id in the arg list
      end
      BRIX11.log_error("Unknown command or namespace [#{cmdspec.join(' ')}]")
      return nil
    end

    def self.init_optparser(options)
      opts = OptionParser.new

      opts.base.append('', nil, nil)  # separator on tail
      opts.on_tail('-f', '--force',
                   'Force all tasks to run even if their dependencies do not require them to.',
                   'Default: off') { options[:force] = true }
      opts.on_tail('-v', '--verbose',
                   'Run with increased verbosity level. Repeat to increase more.',
                   'Default: 0') { |_| options[:verbose] += 1 }
      opts.base.append('', nil, nil)  # separator on tail
      opts.on_tail('-h', '--help',
                   'Show this help message.') { puts; puts opts; puts; exit }
      opts
    end

    def self.parse_args(argv, options)
      # determin command to execute
      if object = parse_command(argv, options)
        optparser = init_optparser(options)
        object.klass.setup(optparser, options)
        argv_org = argv.dup     # backup args
        optparser.order!(argv)  # destructively parse until non-arg encountered (removes '--' args)
        # check if last arg parsed was '--'
        #   if so stuff it back (command might need this)
        argv.insert(0, '--') if argv_org[0...(argv_org.size - argv.size)].last == '--'
        BRIX11.log(2, "executing command #{object.scoped_id}")
        rc = false
        rc = run(options[:command] = object.klass.new(object, options), argv)
        # check if command left '--' in place (or skipped to next); if so remove it
        argv.shift if argv.first == '--'
        return rc
      end
      false
    end

    def self.run(cmd, argv)
      cmd.run(argv)
    end

    def self.descriptions(scope = nil, all = false)
      selection = scope ? { scope => Node.new(scope, [], scoped_commands[scope]) } : commands
      maxlen = determin_max_desc(selection, all)
      maxlen = (((4 + maxlen) / 5) * 5) + 10
      desc = ["%-#{maxlen}s | %s" % ["Command#{scope ? " (#{scope})" : ''}", 'Description']]
      desc << ('-' * (maxlen + 43))
      desc.concat(collect_desc(selection, maxlen, scope, [], all))
    end

    class CmdError < StandardError; end

    class Base
      include BRIX11::LogMethods

      def initialize(entry, options)
        @entry = entry
        @options = options
      end

      attr_reader :entry, :options

      def collection
        @entry.collection
      end

      def root
        Collection[collection].root
      end

      def current_cmd
        @entry.scoped_id
      end

      def console
        BRIX11.console
      end

      def scoped_name
        @scoped_name ||= @entry.scoped_id.gsub(':', '_')
      end
    end # Base
  end # Command
end # BRIX11
