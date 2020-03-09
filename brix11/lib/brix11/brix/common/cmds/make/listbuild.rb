#--------------------------------------------------------------------
# @file    listbuild.rb
# @author  Martin Corino
#
# @brief   Project builder list builder
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module BRIX11

  module Common

    class Make  < Command::Base

      class ListBuilder

        class << self
          public

          def builders
            @builders ||= {}
          end

          private

          def test_config
            @test_config ||= Configure::Configurator.get_test_config
          end


          def is_configured?(cfgs)
            cfgs.all? do |cfg|
              cfg = cfg.lstrip
              if negate = cfg.start_with?('!')
                cfg.slice!(0)
              end
              test_config.include?(cfg.strip) ^ negate
            end
          end

          def check_build(dir)
            builders.each do |gentype, builder|
              return gentype if builder.check_build(dir)
            end
            nil
          end

          def find_build(dir)
            while true
              # check the build dir
              gentype = check_build(dir)
              if gentype
                return [gentype, dir] # type of build found
              else
                # we need to move up
                updir = File.dirname(dir)
                # until we can't anymore
                return nil if updir.empty? || updir == dir
                dir = updir
              end
            end
            nil
          end

          def filter_builds(list, root)
            lnr = 0
            # detect project types and root folders for projects
            build_list = File.open(list).readlines.collect do |line|
              lnr += 1
              line = line.strip
              unless line.empty? || line.start_with?('#')
                path, cfgs = line.split(':')
                cfgs = cfgs.to_s.split(' ')
                if is_configured?(cfgs)
                  dir = File.expand_path(File.dirname(path), root)
                  unless File.directory?(dir)
                    BRIX11.log_warning("Cannot find build directory #{dir} for line ##{lnr} in #{list}.")
                    nil
                  else
                    # check the build directory
                    result = find_build(dir)
                    BRIX11.log_warning("Cannot find build root directory #{dir} for line ##{lnr} in #{list}.") unless result
                    result
                  end
                else
                  nil
                end
              else
                nil
              end
            end.compact.uniq # remove nil entries and duplicates
            # filter out any false positives
            build_list.select do |gentype, path|
              # any path that is a parent to another path is a false positive
              # (search could not find projecttype in original path and traversed
              #  too far up until it a parent root for other tests)
              !build_list.any? {|gtp, bp| bp.start_with?(path) && bp.size>path.size && ['/', '\\'].include?(bp[path.size]) }
            end
          end
        end

        module MPCBuilder
          def self.check_build(dir)
            # an MPC build project dir should contain an .mpc file itself
            # OR it's subdirectories must contain .mpc files
            Dir.glob(File.join(dir, '**', '*.mpc')).any? {|p| File.file?(p)}
          end

          def self.do_build(cmd, path)
            rc = true
            # create new command options
            options = cmd.options.dup
            options[:make] = cmd.options[:make].dup
            options[:make][:genbuild] = false
            options[:make][:project] = path
            options[:make][:subprj] = nil
            options[:make][:lists] = []
            # get project handler
            prj = Project.handler(options[:config][:project_type], options[:config][:project_compiler])
            # if clean requested do so if the project exists
            if options[:make][:clean] && prj.project_exists?(path)
              options[:make][:build] = false # clean only in this pass
              unless Make.new(cmd.entry, options).run(nil)
                BRIX11.log_error("Failed to clean project at #{path}.")
                rc = false
              end
              options[:make][:clean] = false # do not clean anymore
              options[:make][:build] = cmd.options[:make][:build] # reset
            end
            # do we need to build?
            if options[:make][:build]
              # should we (re-)generate?
              if cmd.options[:make][:genbuild]
                options[:genbuild] = GenerateBuild::OPTIONS.dup
                options[:genbuild][:project] = options[:make][:project]
                unless GenerateBuild.new(cmd.entry, options).run(nil)
                  BRIX11.log_error("Failed to generate project for #{path}.")
                  rc = false
                end
              end
              if prj.project_exists?(path)
                unless Make.new(cmd.entry, options).run(nil)
                  BRIX11.log_error("Failed to make project at #{path}.")
                  rc = false
                end
              else
                BRIX11.log_error("Cannot find project at #{path}")
                rc = false
              end
            end
            rc
          end
        end # MPCBuilder

        self.builders[:mpc] = MPCBuilder

        def self.build_all(cmd)
          rc = true
          cmd.options[:make][:lists].each do |root, list|
            BRIX11.log(2, "Checking buildlist %s (root = %s)", list, root)
            BRIX11.log_fatal("Buildlist #{list} does not exist.") unless File.exist?(list)
            build_track = []
            filter_builds(list, root).each do |gentype, path|
              # build each project only once
              # (lists may have multiple lines w. multiple test scripts per project)
              unless build_track.include?(path)
                BRIX11.show_msg("Building #{path}")
                unless builders[gentype].do_build(cmd, path)
                  BRIX11.log_error("Executing build in #{path} failed")
                  rc = false
                end
                build_track << path
              else
                BRIX11.log(2, "Skipping previously built %s", path)
              end
            end
          end
          rc
        end

      end # ListBuilder

    end # Make

  end # Common

end # BRIX11
