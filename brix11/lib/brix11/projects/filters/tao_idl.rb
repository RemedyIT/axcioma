#--------------------------------------------------------------------
# @file    tao_idl.rb
# @author  Martin Corino
#
# @brief   TAO_IDL compiler filter for brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module BRIX11

  module Project

    module Filter

      class TAO_IDLCompiler
        include Formatter::Filter::FilterMethods

        TOOL_PATTERN = /(?<tool>tao_idl)\s.*\s(?<name>\S+\.(p|P)?(idl|IDL))\Z/
        OUTPUT_PATTERNS = [
            [:ignore,     /processing .*/],
            [:ignore,     /tao_idl: .*: found .*/],
            [:error,      /Error - tao_idl:\s+[\"](?<name>.*)[\"], line (?<line>\d+):\s+(?<desc>.*)/]
        ]

        def initialize(verbosity)
          @action = 'Generating'
          @pattern = TOOL_PATTERN
          @tool_verbosity = 2
          @verbosity = verbosity
        end

        # override
        def output_patterns
          OUTPUT_PATTERNS
        end

      end # TAO_IDLCompiler

    end # Filter

  end # Project

end # Filter
