
= BRIX11 generate documentation command

== Collection

common

== Usage

  brix11 [general options] generate documentation [options]

=== options

  -f, --force                      Force all tasks to run even if their dependencies do not require them to.
                                   Default: off
  -v, --verbose                    Run with increased verbosity level. Repeat to increase more.
                                   Default: 0

  -h, --help                       Show this help message.

 == Description

Generate documentation from Asciidoctor sources into the 'docs' directory. To install
Asciidoctor with coderay support as gem run the following command

$ gem install asciidoctor:2.0.10 coderay
