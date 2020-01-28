
= BRIX11 bootstrap command

== Collection

common

== Usage

  brix11 bootstrap [TARGET] [options]

  TARGET := Target component collection to bootstrap. Supported:
            taox11         Bootstraps solely the TAOX11 framework components
            axcioma        Bootstraps the AXCIOMA framework components (default)

=== options

  -t, --tag=COMPONENT:TAG          Override default repository tags for framework components.
                                   Specify as <component id>:<tag>. Supported components:
                                   ACE        DOC Group ACE+TAO repository
                                   MPC        DOC Group MPC repository
                                   ridl       RIDL IDL compiler frontend
                                   taox11     TAOX11 C++11 CORBA ORB repository
                                   ciaox11    CIAOX11 C++11 LwCCM repository
                                   dancex11   DAnCEX11 C++11 D&C repository

  -f, --force                      Force all tasks to run even if their dependencies do not require them to.
                                   Default: off
  -v, --verbose                    Run with increased verbosity level. Repeat to increase more.
                                   Default: 0

  -h, --help                       Show this help message.

== Description

Bootstrap the project.

:*NOTE*
  As the _bootstrap_ command downloads all kind of additional components
  including BRIX11 modules no other commands can be chained. The _bootstrap_ command
  will *always* exit BRIX11 when finished.

