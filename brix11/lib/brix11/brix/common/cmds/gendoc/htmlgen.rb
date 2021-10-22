#--------------------------------------------------------------------
# @file    htmlgen.rb
# @author  Martin Corino
#
# @brief   BRIX11 HTML document generator
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'fileutils'
require 'optparse'
require 'pathname'

module BRIX11

  module Common

    class GenerateDocumentation < Command::Base

      module HTMLGenerator

        OPTIONS = {
          :resourcefolders => {
              'images' => '*.{ico,png,jpg,gif,bmp}',
              'code' => nil,
              'html/stylesheets' => '*.css',
              'html/javascript' => '*.js'
          },
          :resourcepaths => [],
          :adoc_opts => {
            :base_dir => File.join(File.dirname(BRIX11_BASE_ROOT), 'etc', 'docs', 'config'),
            :backend => :html5,
            :mkdirs => true,
            :safe => Asciidoctor::SafeMode::UNSAFE
          }
        }

        class << self

          private
          def resolve_path_var(v)
            Exec.get_run_environment(v) || v
          end

          ## recursively collect resources from a folder
          def collect_resource_folder(docsrc, resdir, mask)
            respath = File.join(docsrc, resdir)
            tgtdir = File.join(X11_DOC_ROOT, resdir)
            BRIX11.log(2, "docgen> Collecting resources from #{respath}")
            Dir.glob(File.join(respath, mask || '*')).each do |res|
              unless File.directory?(res)
                FileUtils.mkdir_p(tgtdir, :verbose => BRIX11.verbose?) unless File.exist?(tgtdir)
                target = File.join(tgtdir, File.basename(res))
                FileUtils.cp(res, target, :verbose => BRIX11.verbose?)
              end
            end
            Dir.glob(File.join(respath, '*')).each do |p|
              if File.directory?(p)
                collect_resource_folder(docsrc, File.join(resdir, File.basename(p)), mask)
              end
            end
          end

          def generate_html_from_folder(srcroot, tgtbase, opts, srcdir=nil)
            srcpath = srcdir ? File.join(srcroot, srcdir) : srcroot.dup
            tgtdir = srcdir ? File.join(X11_DOC_ROOT, 'html', srcdir) : X11_DOC_ROOT.dup
            BRIX11.log(2, "gendoc> Generating HTML from #{srcpath}")
            Dir.glob(srcdir ? File.join(srcdir, '*.adoc') : '*.adoc').each do |src|
              if File.file?(src)
                # setup target file name
                target = [X11_DOC_ROOT, 'html', tgtbase]
                target << srcdir if srcdir
                target << File.basename(src, '.adoc')+'.html'
                target = File.absolute_path(File.join(*target))
                # setup relative resource path attributes
                targetdir = Pathname.new(File.dirname(target))
                attribs = opts[:adoc_attribs].merge(opts[:resourcepaths].inject({}) do |map, respath|
                  map["#{respath.basename}_root"] = respath.relative_path_from(targetdir).to_s
                  map
                end)
                # add current adoc src root
                attribs['adoc_root'] = srcpath
                # add common 'docs' root
                attribs.merge!({ 'docs_root' => Pathname.new(File.join(X11_DOC_ROOT, 'html')).relative_path_from(targetdir).to_s })
                BRIX11.log(2, "gendoc> Rendering HTML from #{src} to #{target}")
                Asciidoctor.render_file(src, opts[:adoc_opts].merge(:to_file => target, :attributes => attribs))
              end
            end
            Dir.glob(srcdir ? File.join(srcdir, '*') : '*').each do |p|
              generate_html_from_folder(srcroot, tgtbase, opts, p) if File.directory?(p)
            end
          end

          public
          def resolve_paths(opts)
            opts[:docsources].each_key do |docs|
              opts[:docsources][docs] = opts[:docsources][docs].collect do |docsrc|
                docsrc.gsub(/\$\{(\w+)\}/) { |_| resolve_path_var($1) }
              end
            end
            opts[:resourcefolders].each_key do |resdir|
              opts[:resourcepaths] << Pathname.new(File.absolute_path(File.join(X11_DOC_ROOT, resdir)))
            end
          end

          def collect_resources(opts)
            # first collect base resources
            collect_resource_folder(File.join(File.dirname(BRIX11_BASE_ROOT), 'etc', 'docs'), 'html/stylesheets', '*.css')
            # iterate all resource folders of all doc sources
            opts[:docsources].keys.each do |docs|
              opts[:docsources][docs].each do |docsrc|
                opts[:resourcefolders].each do |resdir, mask|
                  # lookup every entry in this resource path
                  collect_resource_folder(docsrc, resdir, mask)
                end
              end
            end
          end

          def generate_html(opts)
            ## iterate all 'src' folders (recursively) from all doc sources
            ## and generate HTML documentation from all .adoc files
            opts[:docsources].keys.each do |docs|
              opts[:docsources][docs].each do |docsrc|
                Sys.in_dir(File.join(docsrc, 'src')) do
                  generate_html_from_folder(File.join(docsrc, 'src'), docs, opts)
                end
              end
            end
          end

        end

        def self.run(opts)
          opts = opts.merge(OPTIONS)

          resolve_paths(opts)

          collect_resources(opts)

          BRIX11.show_msg('Generating User documentation')

          generate_html(opts)
        end

      end # HTMLGenerator

    end # GenerateDocumentation

  end # Common

end # BRIX11
