#--------------------------------------------------------------------
# @file    msbuild.rb
# @author  Martin Corino
#
# @brief   MSBUILD filter for brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module BRIX11
  module Project
      module Filter
        class MSBuildFile
          include Formatter::Filter::FilterMethods

          TOOL_PATTERN = /\d+\>((Project\s+"(?<name>.*\.sln)"\s+on\s+node\s.*)|(Project\s+".*"\s+\(\d+\)\s+is\s+building\s+"(?<name>.*\.vcxproj)"\s.*))\Z/
          OUTPUT_PATTERNS = [
              [:warning,     /(?<name>.*)\s+(?<desc>will not be built due to the following missing library: .*)/],
              # msbuild messages
              [:error,      /MSBUILD\s+:\s+[Ee]rror MSB\d+:\s.*\s:\s+(?<desc>.*)\Z/],
          ]
          IGNORE_PATTERNS = [
              [:ignore,       /ValidateSolutionConfiguration:.*\Z/],
              [:ignore,       /Building\s+solution\s+configuration\s.*\Z/],
              [:ignore,       /InitializeBuildStatus:.*\Z/],
              [:ignore,       /Creating\s+".*/],
              [:ignore,       /FinalizeBuildStatus:.*\Z/],
              [:ignore,       /Deleting\s+file\s.*\Z/],
              [:ignore,       /Touching\s+".*/],
              [:ignore,       /Done\s+Building\s+.*/],
              [:ignore,       /Generating\s+Code\.\.\..*\Z/],
              [:ignore,       /All\s+outputs\s+are\s+up-to-date./],
              [:ignore,       /.*\(default target\)\s+->.*/],
              [:ignore,       /.*\(ClCompile target\)\s+->.*/],
          ]

          def initialize(verbosity)
            @action = 'Making'
            @pattern = TOOL_PATTERN
            @verbosity = verbosity
            @tool_verbosity = 1
            @basedir = nil
          end

          # override
          def output_patterns
            OUTPUT_PATTERNS+IGNORE_PATTERNS
          end

        end  # MSBuildFile

        class MSBuild
          include Formatter::Filter::FilterMethods

          OUTPUT_PATTERNS = [
              [:ignore,       /Microsoft\s+\(R\)\s+Build Engine.*/],
              [:ignore,       /Copyright\s+\(C\)\s+Microsoft\s+Corporation.*/],
              [:ignore,       /Build\s+\started\s+.*/],
              [:ignore,       /\d+\>Project ".*"\s+\(\d+\)\s+is\s+building\s+".*\.vcxproj.metaproj"\s.*/],
              [:error,        /MSBUILD\s+:\s+[Ee]rror MSB\d+:\s.*\s:\s+(?<desc>.*)\Z/],
              [:error,        /error\s+MSB\d+:.*\Z/],
              [:error,        /error\s+LNK\d+:.*\Z/],
              [:error,        /Unhandled Exception.*/],
              [:error,        /LINK\s+:\s+[Ff]atal [Ee]rror\s+LNK\d+:\s+(?<desc>.*)\Z/],
          ]

          def initialize(verbosity)
            @action = 'Make'
            @tool = 'msbuild'
            @tool_verbosity = 2
            @verbosity = verbosity
          end


          def match(s)
            @last_output_category = nil
            filter_output(s)
          end

          # override
          def output_patterns
            OUTPUT_PATTERNS+MSBuildFile::IGNORE_PATTERNS
          end

        end # MSBuild
      end # Filter
  end # Project
end # BRIX11
