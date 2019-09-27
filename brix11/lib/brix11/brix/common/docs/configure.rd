
= BRIX11 configure command

== Collection

common

== Usage

  brix11 configure [options]

=== options

  -b, --bits=BITSIZE               Override platform default bitsize (32 or 64).
  -d, --disable=FEATURE            Disable feature (independent of dependency checks).
  -e, --enable=FEATURE             Enable feature (independent of dependency checks).
  -w, --workspace=NAME             Set MWC workspace filename to NAME.mwc.
                                   Default: "workspace".
  -D, --define=MACRO               Define macro for make files as <macro>[=<value>].
  -I, --include=PATH               Include any modules in PATH in configure process.
  -P, --print-config               Print out the current configuration (if any).
  -V, --show-var                   Display the list of configuration variables.
  -W, --with=VARIABLE              Set a configuration variable as "<varname>=<value>".
                                   Use "-V" or "--showvar" to display the list of variables.
  -X, --exclude=PATH               Exclude any modules in PATH from configure process.

  -f, --force                      Force all tasks to run even if their dependencies do not require them to.
                                   Default: off
  -v, --verbose                    Run with increased verbosity level. Repeat to increase more.
                                   Default: 0

  -h, --help                       Show this help message.

== Description

Configure the build environment for the framework. The configure command will
create the following configuration files

 ACE/ACE/ace/config.h
 ACE/ACE/include/makeinclude/platform_macros.GNU
 ACE/ACE/bin/MakeProjectCreator/config/default.features
 taox11/bin/MPC/config/MPC.cfg

  ACE+TAO+MPC configuration files

 .ridlrc

  RIDL configuration with the IDL compiler backends that have to be loaded

 .brix11rc

  BRIX11 configuration

 workspace.mwc

  MPC workspace containing all core libraries and support libraries

:*NOTE*
  As the _configure_ command updates/creates, among others, the configuration for
  BRIX11 itself no other commands can be chained. The _configure_ command
  will *always* exit BRIX11 when finished.

== Example

$ brix11 configure -W aceroot=/somewhere/ACETAO/ACE -W mpcroot=/somewhere/MPC

Configure with custom ACE_ROOT and MPC_ROOT

$ brix11 configure -w myproject --with xercescroot=/someplace/xercesc

Configure with custom MWC workspace name and specified Xerces-C library root

$ brix11 configure -E ciaox11/connectors/psdd4ccm

Configure excluding the psdd4ccm connector module.
