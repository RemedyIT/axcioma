
= BRIX11 host build command

== Collection

  common

== Usage

  brix11 host build [options]

=== options

  -c, --clean                      Clean only.
  -r, --rebuild                    Clean and than build.
  -G, --generate                   Always (re-)generate project files
                                   Default: only generate if project files do not exist.
  -N, --no-redirect                Do not redirect output from child process..
                                   Default: redirect and filter output.

  -f, --force                      Force all tasks to run even if their dependencies do not require them to.
                                   Default: off
  -v, --verbose                    Run with increased verbosity level. Repeat to increase more.
                                   Default: 0

  -h, --help                       Show this help message.

== Description

Build the local, minimal, crossbuild host tools.
The _brix11_ _configure_ command sets up a local, minimalized crossbuild host environment in
the $X11_BASE_ROOT/HOST folder when a crossbuild is configured without specifying an explicit
external host environment. This command allows to generate the project files and (re-)build the
minimum required host tool binaries for building the crossbuild itself.

== Example

$ brix11 host build

Build the host tools.

$ brix11 host build -r

Rebuild the host tools (clean first and than make again).

$ brix11 host build -G

Force (re-)generation of project files before making the host tools.
