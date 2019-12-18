
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
  -T, --target=NAME                Specify target platform name.
                                   Default: none (target is host os)
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

When a crossbuild is configured without specifying an explicit external host environment (a TAOX11 or AXCIOMA build tree) a local,
minimalized crossbuild host environment is set up in the $X11_BASE_ROOT/HOST folder.
The minimum required host tool binaries can than be build using the _brix11_ _host_ _build_ command.

The _brix11_ _host_ _build_ command is *only* available when a crossbuild with local, minimalized, host environment is configured.

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

$ brix11 configure --target yocto \
  -W targetsysroot=../YOCTO/sysroots/aarch64-poky-linux \
  -W crosscompile_prefix=aarch64-poky-linux- \
  -W path=/path/to/host/cross/compiler/binaries

Configure crossbuild for a Yocto aarch64 target with minimal, local, host environment set up in $X11_BASE_ROOT/HOST.
BRIX11 reads (optional) target build specs from $X11_BASE_ROOT/etc/<target>.json if available.

$ brix11 configure --target yocto \
  -W x11_host_root=/path/to/host/x11/build/tree \
  -W targetsysroot=../YOCTO/sysroots/aarch64-poky-linux \
  -W crosscompile_prefix=aarch64-poky-linux- \
  -W path=/path/to/host/cross/compiler/binaries

Configure crossbuild for a Yocto aarch64 target with explicit external host environment set up in *x11_host_root*.
BRIX11 reads (optional) target build specs from $X11_BASE_ROOT/etc/<target>.json if available.
