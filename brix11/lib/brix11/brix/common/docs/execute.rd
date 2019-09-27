
= BRIX11 execute command

== Collection

common

== Usage

  brix11 execute [options] PROGRAM [arguments [--]]

=== options

  -d, --detach                     Specifies to detach from child process after execution.
                                   Default: wait for child process to terminate

  -f, --force                      Force all tasks to run even if their dependencies do not require them to.
                                   Default: off
  -v, --verbose                    Run with increased verbosity level. Repeat to increase more.
                                   Default: 0

  -h, --help                       Show this help message.

== Description

Execute a process in the brix11 environment.

== Example

$ brix11 exec server

Executes the program executable 'server'.
