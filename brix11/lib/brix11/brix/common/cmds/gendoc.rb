#--------------------------------------------------------------------
# @file    gendoc.rb
# @author  Martin Corino
#
# @brief   BRIX11 document generator
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'brix11/command'

module BRIX11
  module Common

    class GenerateDocumentation < Command::Base

      DESC = 'Generate documentation from ASCIIDoctor sources.'.freeze

      OPTIONS = {
        :docsources => {
            'brix11' => ["#{File.join(BRIX11_BASE_ROOT, 'docs')}"]
          },
        :adoc_attribs => {}
      }

      X11_DOC_ROOT = File.expand_path(File.join(File.dirname(BRIX11_BASE_ROOT), 'docs'))

      def self.setup(optparser, options)
        # check ASCIIDoctor availability
        begin
          require 'asciidoctor'
          require 'asciidoctor/extensions'
        rescue LoadError
          BRIX11.log_fatal("This command requires the installation of the ASCIIDoctor GEM!")
        end
        # load document generator(s)
        Dir.glob(File.join(ROOT, 'cmds', 'gendoc', '*.rb')).each { |p| require "brix/common/cmds/gendoc/#{File.basename(p)}"}
        # initialize options and option parser
        options[:gendoc] = OPTIONS.dup
        optparser.banner = "#{DESC}\n\n"+
                           "Usage: #{options[:script_name]} gen[erate] doc[umentation] [options]\n\n"
      end

      def run(argv)
        HTMLGenerator.run(options[:gendoc])

        true
      end

      Command.register('generate:documentation', DESC, Common::GenerateDocumentation)
    end # GenerateDocumentation

  end # Common
end # BRIX11
