#--------------------------------------------------------------------
# @file    adoc-ext.rb
# @author  Martin Corino
#
# @brief   BRIX11 ASCIIDoctor extensions
#
# @copyright Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
#--------------------------------------------------------------------

module BRIX11

  module Common

    class GenerateDocumentation < Command::Base

      ## Custom 'dirlist' block macro extension
      class DirListBlockMacro < Asciidoctor::Extensions::BlockMacroProcessor
        use_dsl

        named :dirlist

        def collect_dirlist(glob, recurse=false, indent=0)
          (indent>0 ? [] : ['.', '..']).concat(Dir.glob(glob).collect do |p|
            entry = "#{' ' * indent}#{File.basename(p)}#{File.directory?(p) ? '\\' : ''}"
            if File.directory?(p) && recurse
              entry << "\n" << collect_dirlist(File.join(p, File.basename(glob)), recurse, indent+2)
            end
            entry
          end).join("\n")
        end

        def process parent, target, attrs
          docdir = (parent.document.attributes.has_key? 'docfile') ?
            File.dirname(parent.document.attributes['docfile']) : Dir.getwd
          # STDERR.puts "#{docdir} + #{target} => #{File.expand_path(File.join(docdir, target))}"
          # STDERR.puts attrs
          recurse = (attrs['recurse'] || (attrs.values.include?('recurse'))) ? true : false
          glob = File.expand_path(File.join(docdir, target))
          adoc = collect_dirlist(glob, recurse)
          create_listing_block parent, adoc, attrs #, subs: nil
        end
      end

      # register extension
      Asciidoctor::Extensions.register do
        block_macro DirListBlockMacro
      end

    end # GenerateDocumentation

  end # Common

end # BRIX11
