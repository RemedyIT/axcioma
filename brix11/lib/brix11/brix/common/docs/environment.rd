
= BRIX11 environment command

== Collection

common

== Usage

  brix11 environment [options]

=== options

  -A, --all                        Specifies to print all environment variables.
                                   Default: print only BRIX11 specific environment
  -f, --file=FILE                  Specifies filename to write environment settings to.
                                   Default: print to console

      --force                      Force all tasks to run even if their dependencies do not require them to.
                                   Default: off
  -v, --verbose                    Run with increased verbosity level. Repeat to increase more.
                                   Default: 0

  -h, --help                       Show this help message.

== Description

Prints the (additionally) required environment settings needed to run the development tools for
X11 development.
This command will only output those settings that were added by BRIX11 to the existing environment in which
BRIX11 is executed.

The settings are printed in command form such that the command output can be used to update the environment
to be able to run X11 development tools outside BRIX11.
This is useful for advanced users that need to go beyond the offered functionality of BRIX11.

The output is (OS) platform specific.

== Example

$ brix11 env

Prints the required environment settings to the console.

$ brix11 env > myenv

Writes the required environment settings to the file ./myenv.

$ `brix11 env`

In a Unix shell performs command expansion and executes the printed environment setting commands
thereby updating the settings of the current shell.
Alternatively the form '$(brix11 env)' could be used.