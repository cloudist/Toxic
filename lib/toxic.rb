require "toxic/version"
require 'gli'

include GLI::App

program_desc 'Toxic, a command line tool for creating xcode project from template'
version Toxic::VERSION

require 'toxic/command/project'

run(ARGV)