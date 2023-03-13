#--------------------------------------------------------------------
# @file    process.rb
# @author  Martin Corino
#
# @brief   Subprocess support for scaffolding tool brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module BRIX11
  module Exec
    self.singleton_class.class_eval do
    private
      def run_env
        unless @run_env
          @run_env = {}
          # add all user environment vars
          (BRIX11.options.config.user_environment || {}).each_pair do |k,v|
            # expand embedded var references
            @run_env[k] = v.gsub(/\$\{?([^\s\/\}:;]+)\}?/) { |m| ENV[$1] }
          end
        end
        @run_env
      end

      def childs
        @childs ||= []
      end

      def register_child(process)
        childs << process
      end

      def unregister_child(process)
        childs.delete(process)
      end

      def spawner
        @spawner ||= Class.new do
          attr_reader :pid, :status
          def initialize(args)
            @status = nil
            _oldpath = ENV['PATH']
            ENV['PATH'] = args.first['PATH'] if Hash === args.first && args.first.has_key?('PATH')
            @pid = Kernel.spawn(*args)
          ensure
            ENV['PATH'] = _oldpath
          end

          def wait(noblock = false)
            begin
              rc, @status = Process.waitpid2(@pid, noblock ? Process::WNOHANG : 0)
            end until noblock || (rc == @pid && @status)
            rc == @pid && @status && nil != @status.success?
          rescue Errno::ECHILD
            @pid = nil
            true
          end

          def has_terminated?
            @pid.nil? || (@status && @status.pid == @pid && nil != @status.success?)
          end

          def is_running?
            !has_terminated?
          end

          def exitcode
            (has_terminated? && @pid) ? @status.exitstatus : -1
          end
        end
      end

      def spawn_cmd(cmd, argv, opts)
        outputrd, outputwr = nil
        inputrd, inputwr = nil
        input_str = false
        spawn_args = []
        if opts[:env] || !run_env.empty?
          spawn_args << if opts[:env]
                          if opts[:overwrite_env]
                            opts[:env]
                          else
                            run_env.merge(opts[:env])
                          end
                        else
                          run_env
                        end
        end
        spawn_args << cmd
        spawn_args.concat argv
        spawn_opts = {}
        if (opts[:capture] || opts[:filter]) && (!opts[:detach] || String === opts[:capture])
          outputrd, outputwr = IO.pipe
          if opts[:filter]
            spawn_opts[[:out, :err]] = outputwr
          else
            case opts[:capture]
            when :out
              spawn_opts[:out] = outputwr
            when :err
              spawn_opts[:err] = outputwr
            when :all
              spawn_opts[[:out, :err]] = outputwr
            when String
              spawn_opts[[:out, :err]] = [opts[:capture], 'w']
            else
              raise ArgumentError, "Illegal capture source #{opts[:capture]}"
            end
          end
        end
        if opts[:input] && !opts[:detach]
          case opts[:input]
          when Proc
            inputrd, inputwr = IO.pipe
            spawn_opts[:in] = inputrd
          when IO
            spawn_opts[:in] = opts[:input]
          else
            input_str = true  # input opts[:input] as string
            inputrd, inputwr = IO.pipe
            spawn_opts[:in] = inputrd
          end
        end
        spawn_args << spawn_opts

        process = spawner.new(spawn_args) unless BRIX11.dryrun?
        outputwr.close if outputwr
        outputwr = nil
        inputrd.close if inputrd
        inputrd = nil
        return [true, nil, ''] if BRIX11.dryrun?

        if opts[:detach]
          ::Process.detach(process.pid)
          return [true, nil, nil]
        end

        register_child(process)

        callback = block_given? # is a capture block specified?
        output = ''
        if input_str
          inputwr << opts[:input]
          inputwr.close
          inputwr = nil
        end
        begin
          opts[:input].call(inputwr) if Proc === opts[:input]
          process.wait(outputrd != nil)
          if outputrd
            while (line = outputrd.gets)
              opts[:filter].print(line) if opts[:filter]
              if callback
                yield(line)
              else
                output << line
              end
            end
          end
        end until process.has_terminated?

        unregister_child(process)

        if outputrd
          line = outputrd.read
          opts[:filter].print(line) if opts[:filter]
          opts[:filter].flush if opts[:filter]
          if callback
            yield(line)
          else
            output << line
          end
        end
        yield(process.status) if callback

        return [process.status.success? == true, process.exitcode, output]
      ensure
        outputrd.close if outputrd
        outputwr.close if outputwr
        inputrd.close if inputrd
        inputwr.close if inputwr
      end
    end

    def self.mswin?
      Sys.mswin?
    end

    def self.cpu_cores
      Sys.get_cpu_cores
    end

    def self.max_cpu_cores
      Sys.get_max_cpu_cores
    end

    def self.run_environment
      run_env.dup
    end

    def self.full_environment
      ENV.to_hash.merge(run_env)
    end

    def self.has_run_environment?(env)
      run_env.has_key?(env) || (BRIX11.use_environment? && ENV[env])
    end

    def self.update_run_environment(env, val, op = :replace, sep = File::PATH_SEPARATOR)
      # if we add to env vars make sure to get current either from local env or global (if used)
      cur = [get_run_environment(env)] unless op == :replace
      case op
      when :append
        run_env[env] = (cur << val).flatten.join(sep)
      when :prepend
        run_env[env] = ([val].concat(cur)).flatten.join(sep)
      when :replace
        run_env[env] = [val].flatten.join(sep)
      else
        raise ArgumentError, "Invalid update_run_environment operation [#{op}]"
      end
      run_env[env]
    end

    def self.get_run_environment(env, force_use_env = false)
      run_env[env] || ((BRIX11.use_environment? || force_use_env) ? ENV[env] : nil)
    end

    def self.reset_run_environment
      run_env.clear
    end

    # runcmd cmd [, arg[, arg[, ...]]] [, opts = {}] [, &block]
    #
    # opts = {
    #   env: { 'var' => 'value', ... },
    #   overwrite_env: true|false
    #   chdir: 'directory',
    #   capture: :out|:err|:all|string, if string => redirect all to file named by string
    #   input: String|IO|Proc,
    #   silent: true|false,
    #   detach: true|false,
    #   filter: Formatter::Filter
    # }
    #
    # If :env is specified it's settings will be merged (overwriting) with the default
    # run_environment unless :overwrite_env is also specified in which case :env settings
    # will be used *instead* of the default run environment.
    #
    # If block_given? the block will be called with a Process::Status object
    # when the child process has terminated.
    # When the :capture option has been specified a given block will be called
    # for each line of captured output with the output as argument as long as
    # the child process has not terminated yet and a Process::Status object as
    # argument when the child process has terminated.
    # When the :input option is specified the child process's STDIN will be
    # redirected to receive input from the source specified:
    # - for a string or a proc a pipe will be created from which the reader end
    #   will be provided to the child and the writer end will be used to write
    #   the string to or passed as the argument to the block
    # - an IO will be assumed to be a readable IO pipe end and provided to the child
    #   as STDIN
    #
    # Returns an array of 2-3 elements:
    # [0] = true if child has run successfully, false otherwise
    # [1] = child's exit code
    # [2] = the child's captured output if :capture was specified and no block
    #
    def self.runcmd(cmd, *args)
      argv = []
      rc = [false]
      opts = {}

      while !args.empty? && !(Hash === args.first)
        argv << args.shift.to_s
      end
      opts.merge!(args.shift) if Hash === args.first
      raise ArgumentError, 'Too many arguments.' unless args.empty?
      if opts[:chdir]
        Sys.in_dir(opts[:chdir]) do
          BRIX11.log(opts[:silent] ? 2 : 1, "> #{cmd} #{argv.join(' ')}")
          block_given? ? spawn_cmd(cmd, argv, opts, &Proc.new) : spawn_cmd(cmd, argv, opts)
        end
      else
        BRIX11.log(opts[:silent] ? 2 : 1, "> #{cmd} #{argv.join(' ')}")
        block_given? ? spawn_cmd(cmd, argv, opts, &Proc.new) : spawn_cmd(cmd, argv, opts)
      end
    end

    def self.handle_interrupt
      childs.each do |process|
        begin
          ::Process.kill(:INT, process.pid)
          unless process.wait(true)
            ::Kernel.sleep(0.01)
            ::Process.kill(:TERM, process.pid) unless process.wait(true)
          end
        rescue Errno::ECHILD
        rescue Errno::ESRCH
        end
      end
    end
  end # Exec

  ::Signal.trap(:INT) do
    STDERR.puts
    Exec.handle_interrupt
    BRIX11.log_error ('interrupted')
    ::Kernel.exit(-1)
  end
end # BRIX11
