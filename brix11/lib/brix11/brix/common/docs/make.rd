
= BRIX11 make command

== Collection

common

== Usage

  brix11 [general options] make [options] [PROJECT [make-options]]|[-- make-options]

=== options

  PROJECT := Path to project folder or name of subproject. If both PROJECT and SUBPRJ
             are specified, PROJECT should be path and SUBPRJ subproject name.

  -c, --clean                      Clean project only.
  -r, --rebuild                    Clean and than build project.
  -p, --project=SUBPRJ             Specifies path to or name of (sub-)project to build.
      --no-gen-build               Do not automatically generate build files using MPC if they do not exist yet.
      --debug                      Debug mode. Default: Off
      --release                    Release mode. Default: On
  -L, --build-list=BUILDLIST       Build the list of projects specified by BUILDLIST.
                                   BUILDLIST specifies a buildlist file and optional root as: [<root>=]<listfile>.
                                   If no root is specified it defaults to the location of the listfile.
  -N, --no-redirect                Do not redirect output from child process..
                                   Default: redirect and filter output.

  -f, --force                      Force all tasks to run even if their dependencies do not require them to.
                                   Default: off
  -v, --verbose                    Run with increased verbosity level. Repeat to increase more.
                                   Default: 0

  -h, --help                       Show this help message.

=== Environment variables

In order to control the number of cpu's to use with project types supporting multicore building, the environment variable
BRIX11_NUMBER_OF_PROCESSORS can be set to overrule system based defaults.
By default (without BRIX11_NUMBER_OF_PROCESSORS defined) BRIX11 will run builds for project types supporting
multicore (or parallel) building using all cpu cores available.
When BRIX11_NUMBER_OF_PROCESSORS is set to a number less then the system defined number of cpu cores, BRIX11 will at
most use the number of cpu cores specified by BRIX11_NUMBER_OF_PROCESSORS to run the build.
Currently multicore building is supported for msbuild based project types ('vs2015' and 'vs2017') as well as the
'gnuautobuild' project type.

== Description

Run the project type specific build (make) tool to build (make) the project artifacts like IDL generated code, source
code compilations and linked library and executable binaries.

== Example

$ brix11 make

Makes the default toplevel project at the current location (f.i. runs GNU make for the 'GNUmakefile' in the
current directory for the 'gnuace' or 'gnuautobuild' project types).

$ brix11 make taox11

Makes either the 'taox11' subproject at the current location (f.i. runs GNU make for the 'GNUmakefile.taox11' in the
current directory for the 'gnuace' or 'gnuautobuild' project types) or the default toplevel project in the
./taox11 subdirectory (f.i.runs GNU make for the 'GNUmakefile' in the ./taox11 directory for the 'gnuace' or
'gnuautobuild' project types).

$ brix11 make -p Hello_X11_Idl test/hello

Makes the 'Hello_X11_Idl' subproject in the ./test/hello subdirectory (f.i. runs 'GNUmakefile.Hello_X11_Idl' in the
./test/hello subdirectory for the 'gnuace' or 'gnuautobuild' project types).

$ brix11 -t nmake:vc14x64 make --debug hello

Makes the hello project, runs nmake for the 'Makefile.hello.mak' in the
current directory for the 'nmake' project types  with configuration settings  NO_EXTERNAL_DEPS=1 and CFG=x64 Debug

$ brix11 make -r -- -v

Rebuild ,by using the option -r, the default toplevel project at the current location and uses the make-option to
print the version of make

> set BRIX11_NUMBER_OF_PROCESSORS=3

> brix11 -t vs2015 make hello

Makes the hello project, runs msbuild for the 'hello.sln' in the current directory with /maxcpucount:3 (assuming
BRIX11_NUMBER_OF_PROCESSORS <= nnumber of cpu cores in computer).
