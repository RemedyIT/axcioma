
= BRIX11 generate build command

== Collection

common

== Usage

  brix11 [general options] gen[erate] bui[ld] [options] [PROJECT [mwc-options]]|[-- mwc-options]]

=== options

  PROJECT := Path to project folder or name of subproject. If both PROJECT and SUBPRJ
             are specified, PROJECT should be path and SUBPRJ subproject name.

  -S, --static                     Generate for static build.
  -e, --enable=FEATURE             Enable feature(s). If specifying more than 1 separate by ','
  -d, --disable=FEATURE            Disable feature(s). If specifying more than 1 separate by ','
  -p, --project=SUBPRJ             Specifies path to or name of (sub-)project to generate for.
  -I, --include=DIR                Include directory.
  -X, --exclude=DIR                Exclude directory.
  -f, --force                      Force all tasks to run even if their dependencies do not require them to.
                                   Default: off
  -v, --verbose                    Run with increased verbosity level. Repeat to increase more.
                                   Default: 0

  -h, --help                       Show this help message.


== Description

Run MPC to generate the project type specific project files (f.i. generates GNU Makefiles for the 'gnuace' and
'gnuautobuild' project types).
Project files are generated recursively either from the designated directory into it's subdirectories or from the
directories listed in the specified .mwc files. See the MPC documentation for more information.
MPC uses so-called MWC-files (.mwc extension) to define 'workspaces' limiting the (sub-)projects to include (see
MPC documentation for more details).
(Sub-)projects are defined in MPC-files (.mpc extension) each of which can define 1 or more (sub-)projects.
Workspace files are optional. By default MPC will recursively traverse a directory tree (from a specified starting
point) and handle all MPC-files it finds.
For each (sub-)project defined (and included according to selection criteria; see MPC docs) MPC will generate a
project type specific project file; f.i. a GNU makefile for the 'gnuace' and 'gnuautobuild' project types with the
name 'GNUmakefile.mpc_project_id' (the 'mpc_project_id' is the project id specified in the MPC-files).
When generating for a complete workspace MPC will also generate a toplevel, project type specific, workspace file; f.i.
a GNU makefile named 'GNUmakefile' for the 'gnuace' and 'gnuautobuild' project types.

== Example

$ brix11 gen build

Generates project files for 'gnuace' (default) projects and subprojects in a workspace starting in the current directory and
recursively in it's subdirectories.

$ brix11 gen build taox11

Generates either the (sub-)projects defined in the 'taox11.mpc' file in the current directory (in which case no
workspace file is generated) or all (sub-)projects belonging to the workspace starting in the ./taox11 directory
and it's subdirectories.

$ brix11 gen build -p hello test/hello

Generates all (sub-)projects defined in the 'hello.mpc' file in the ./test/hello directory. In this case no
workspace file is generated.

$ brix11 -t nmake:vc143x64 gen build -- -version

Generates project files for 'nmake' projects and subprojects using the Visual Studio 2022 64bit compiler, in a workspace
starting in the current directory and recursively in it's subdirectories, using the mwc options
'-type nmake -value_template platforms=x64 -base vc143nmake'.
Also shows the MPC version by adding the mwc-option '-version'.


