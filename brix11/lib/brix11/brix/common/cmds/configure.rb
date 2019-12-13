#--------------------------------------------------------------------
# @file    configure.rb
# @author  Martin Corino
#
# @brief  Configure tool
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/command'
module BRIX11
  module Common

    class Configure  < Command::Base

      DESC = 'Configure the project.'.freeze

      OPTIONS = {
        :includes => [],
        :excludes => [],
        :variables => {},
        :features => {}
      }

      def self.setup(optparser, options)
        options[:configure] = OPTIONS.dup
        optparser.banner = "#{DESC}\n\n"+
                           "Usage: #{options[:script_name]} configure [options]\n\n"

        optparser.on('-b', '--bits', '=BITSIZE', Integer, 'Override platform default bitsize (0, 32 or 64).',
                                                          'Specifying 0 disables explicit bitsize setting.') do |v|
          BRIX11.log_fatal("Invalid bitsize specified [#{v}]. Supported sizes are 0, 32 or 64.") unless [0, 32,64].include?(v.to_i)
          options[:configure][:bitsize] = v.to_i
        end

        optparser.on('-d', '--disable', '=FEATURE', 'Disable feature (independent of dependency checks).') do |v|
          options[:configure][:features][v.to_sym] = false
        end
        optparser.on('-e', '--enable', '=FEATURE', 'Enable feature (independent of dependency checks).') do |v|
          options[:configure][:features][v.to_sym] = true
        end

        optparser.on('-w', '--workspace', '=NAME', 'Set MWC workspace filename to NAME.mwc.', 'Default: "workspace".') do |v|
          options[:configure][:workspace] = v
        end

        optparser.on('-T', '--target', '=NAME', 'Specify target platform name.', 'Default: host') do |v|
          options[:configure][:target] = v
        end

        if /linux/i =~ Platform.platform_os
          optparser.on('-D', '--define', '=MACRO', 'Define macro for make files as <macro>[=<value>].') do |v|
            options[:configure][:defines] ||= {}
            macro, val = v.split('=')
            options[:configure][:defines][macro] = val
          end
        end

        optparser.on('-I', '--include', '=PATH', 'Include any modules in PATH in configure process.') do |v|
          options[:configure][:includes] << File.expand_path(v)
        end

        optparser.on('-P', '--print-config', 'Print out the current configuration (if any).') do
          Configurator.print_config(options[:configure][:workspace])
          exit
        end

        optparser.on('-V', '--show-var', 'Display the list of configuration variables.') do
          # load all rc files
          rclist  = RCSpec.load_all_rc(options[:configure][:includes], options[:configure][:excludes])
          # Show list of variables available to set through '--with'
          STDOUT.puts
          STDOUT.puts 'BRIX11 configure configuration variables'
          STDOUT.puts '----------------------------------------'
          vars = rclist.values.collect {|rc| rc.dependencies.values.collect {|dep| dep.environment.values}}.flatten
          vars.prepend(Common::Configure::RCSpec::Dependency::Environment.new(:path) do
            name 'PATH'
            description 'Executable searchpath addition (prepended).'
          end)
          vars.each {|v| STDOUT.puts('%-15s  %s' % [v.variable.to_s, v.description]) }
          STDOUT.puts
          exit
        end

        optparser.on('-W', '--with', '=VARIABLE', 'Set a configuration variable as "<varname>=<value>".' ,
                                                  'Supports \$VAR and \${VAR}-form variable expansion.',
                                                  'Use "-V" or "--showvar" to display the list of variables.') do |v|
          var, val = v.split('=')
          BRIX11.log_fatal("Missing required value for configuration variable in [--with #{v}].") unless val
          options[:configure][:variables][var.to_sym] = val
        end

        optparser.on('-X', '--exclude', '=PATH', 'Exclude any modules in PATH from configure process.') do |v|
          options[:configure][:excludes] << File.expand_path(v)
        end
      end

      def run(argv)
        conf_opts = options[:configure]

        configurator = Configurator.new(conf_opts)

        configurator.process

        configurator.generate

        BRIX11.show_msg('Configure finished. Exiting BRIX11.')
        exit(0)
      end

      Command.register('configure', DESC, Common::Configure)
    end # Configure

    Dir.glob(File.join(ROOT, 'cmds', 'configure', '*.rb')).each { |p| require "brix/common/cmds/configure/#{File.basename(p)}"}

  end # Common

end # BRIX11
