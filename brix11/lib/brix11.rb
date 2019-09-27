#--------------------------------------------------------------------
# @file    brix11.rb
# @author  Martin Corino
#
# @brief   Main loader for scaffolding tool brix11
#
# @copyright Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
#--------------------------------------------------------------------

module BRIX11
  VERSION = '1.1.0'
  VERSION_MAJOR,
      VERSION_MINOR,
      VERSION_RELEASE, = VERSION.split('.').collect {|e| e.to_i}
  COPYRIGHT = "Copyright (c) 2014-#{Time.now.year} Remedy IT Expertise BV, The Netherlands".freeze

  def self.root_path
    f = File.expand_path(__FILE__)
    f = File.expand_path(File.readlink(f)) if File.symlink?(f)
    libdir = File.dirname(f)
    $: << libdir unless $:.include?(libdir)
    File.dirname(libdir)
  end

  BRIX11_BASE_ROOT = self.root_path
end

require 'brix11/base'

if $0 == __FILE__
  BRIX11.run
end
