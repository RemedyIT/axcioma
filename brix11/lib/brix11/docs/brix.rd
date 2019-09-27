
= BRIX11 Scaffolding tool

== Usage

  brix11 [general options] command [command options] [ [--] command [command options] [...]]

=== general options


  -I, --include=PATH               Adds search path for Brix collections.
                                   Default: loaded from ~/.brix11rc and/or ./.brix11rc
  -t, --type=TYPE[:COMPILER]       Defines project type used with optional compiler selection.
                                   Use --show-types to list available project types and active default.
      --show-types                 List available project types (with compiler options) and active default
      --add-templates=PATH         Add a template library basepath to be evaluated before standard brix templates.
  -E, --environment                Environment settings overrule BRIX11 (like RIDL_ROOT, ACE_ROOT, TAOX11_BASE_ROOT etc.).
                                   Default: off
  -D, --define=VARIABLE            Define an additional environment variable for BRIX11 commands.
                                   Separate (optional) value by '=' like VAR=VAL. By default value will be '1'.
                                   Supports $VAR and ${VAR}-form variable expansion.
  -x, --crossbuild                 Define crossbuild configuration for BRIX11 commands.
                                   Requires definition of X11_HOST_ROOT and X11_TARGET_ROOT environment variables.

  -c, --config=BRIX11RC            Load config from BRIX11RC file.
                                   Default:  ~/.brix11rc and/or ./.brix11rc
      --write-config=[BRIX11RC]    Write config to file and exit.
                                   Default: ./.brix11rc
      --show-config=[BRIX11RC]     Print specified or active config and exit.
                                   Default: active configuration

  -l, --list-collections           List available brix collections and exit.
  -L, --list=[all]                 List available brix (for selected collection) and exit.
                                   Also list collections of overridden entries if 'all' specified.
      --scope=COLLECTION           Defines collection scope for filtering commands.
                                   Default: no scope

  -V, --version                    Show version information and exit.

  -f, --force                      Force all tasks to run even if their dependencies do not require them to.
                                   Default: off
  -n, --dryrun                     Perform dry run (no destructive/persistent actions).
                                   Default: off
  -v, --verbose                    Run with increased verbosity level. Repeat to increase more.
                                   Default: 1
  -q, --quiet                      Run silent (verbosity 0).
                                   Default: 1
  -C, --capture=FILENAME           Capture command output to file FILENAME.
                                   Default:  do not capture output.
  -h, --help                       Show this help message.
                                   Use 'brix11 command -h' to show command (option specific) help.

=== Environment variables

It is possible, instead of using the general option '-v' to set the verbosity level, to set
the verbosity level with the environment variable BRIX11_VERBOSE=n, with n is 1,2,3,...


== Description

BRIX11 implements a pluggable scaffolding tool framework with which a user can execute a multitude of
commands to automate various X11 development related tasks like (but not limited to):

  - generate '.mpc' files
  - drive project file generation through MPC
  - generate (starter) IDL files
  - generate (starter) implementations for CORBA server and/or client applications
  - generate (starter) implementations for CORBA servants
  - generate standard run scripts for the PerlACE test framework

BRIX11 is targeted at ease of use and meant to help you become productive with the X11 development packages
as soon as possible.
BRIX11 integrates with MPC for project file (make files or other) generation, build tools like GNU make
for running compilation and linking tasks through the MPC generated project files and embeds RIDL for
inline IDL parsing and code generation.
BRIX11 relieves you from the burden to set up the necessary environment (variables) needed to run compile,
link and/or run your X11 applications.

BRIX11 uses plugin sets of commands, so-called *brix* *collections*.
Using the *-l* switch you can see the different collections currently being loaded.
Using the *-L* switch you can list active brix (commands) available from these collections. The list shows
the name for the command and the collection where it came from'.

BRIX11 uses scoped names for brix allowing for logical grouping of brix like a set of brix in a 'generate'
namespace. The leading name segments are known as *namespaces*, the tail segment as the *command* *id*.
When specifying a command name on the command line BRIX11 allows you to provide the name either as a
'space separated' sequence like 'generate build' or as the 'colon separated' form like 'generate:build'.

To make it easier for experienced users BRIX11 allows you to shorten the provided name segments to the
shortest *unique* form with a minimum of 3 characters. So the example above could also be used as 'gen bui'
or 'gen:bui'.
BRIX11 also allows commands to define *aliases* for name segments to allow for shorter unique ids where
regular shortening of names would create clashes with other similarly named commands.
In the case of the distinct commands 'generate server' and 'generate servant' for example regular shortening
would already cause a clash at the sequence 'gen serv'. To provide for that both commands define aliases for
their command ids, respectively 'srv' for 'server' and 'svt' for 'servant'. This allows to specify the
'generate server' command as 'gen srv' and 'generate servant' as 'gen svt' (or 'gen:svt').

The brix collection id by itself also provides a namespace for a command which by default does not need to
be provided as BRIX11 will register each command primarily based on the command name.
As a result any command from a collection with a name identical to a command loaded from a previously loaded
collection (as determined by the order of the brix collection include paths) will override the previously loaded
command.
This behaviour is intentional and allows one to explicitly use this mechanism to enhance existing commands.
BRIX11 however also maintains collection specific registrations of the commands allowing to specify (possibly
overridden) commands from a specific collection.
The *-Lall* option will display a list including all overridden commands.

To specify a collection specific command there are two options:
  1. use the '--scope' option to specify a collection scope for the entire
     command line
  2. add the collection id to the scoped name specification like
     'common generate build' (or 'com:gen:build')

BRIX11 also allows specifying multiple commands on a single command line.
In these cases BRIX11 will execute the commands specified sequentially in the order specified. Commands
specified later on the commandline will only be executed if all preceding commands succeeded.

By default BRIX11 will define a full set of environment variables required to run all of the development
tools it uses overriding anything set in the environment which it inherited itself.
You can use the *environment* command to show all the variables BRIX11 sets (see 'brix11 help env' for more
details.
You can use the *-E* switch to change this behaviour and be able to define your own version of the environment
variables BRIX11 uses in the environment in which *brix11* is executed.
Alternatively you can use the *-D* switch to define your own environment variables that BRIX11 will add to
it's command environment. BRIX11 supports expansion of existing environment variables in the variable values
you define.

So you could f.i. expand the *PATH* variable used by BRIX11 by using:
  'brix11 -D PATH=\$PATH:/my/additional/path <command>'

You can also make BRIX11 remember your custom variable definitions by writing your definitions (and optionally
other custom settings) to a BRIX11 rc file using the *--write-config* switch.
BRIX11 will write any settings specified for:
 '-I'
 '-t'
 '--add-template'
 '-E'
 '-D'
encountered *before* the *--write-config* switch to the rc file specified.

On startup BRIX11 reads in the following rc files (in order):
  - the global '.brixrc' file located in the root of your HOME directory
  - the BRIX11 rc file(s) listed in the *BRIX11RC* environment variable's value
    (multiple files separated by ':' or ';')
  - the BRIX11 rc file(s) found in all directories from the root to the current
    working directory (in that order)
RC files will only be loaded once.

== Example

  brix11 generate make

This will run MPC in the working directory (recursing into any subdirectories) to generate appropriate
project files (depending on the configured project type) based on any .mpc files found.
