#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'lib/options'
require 'lib/package/spm'
require 'optparse'
require 'yaml'

def parse_options(argv)
  parser, options = OptionParser.new, {}
  parser.on("-b", "--build") { options[:action] = :build }
  parser.on("-i", "--install") { options[:action] = :install }
  parser.on("--config_file=FILE", "YAML configuration file that specifies package structure", String) { |file| options[:config] = file }
  parser.on("--package_file=FILE", "SPM file, that will be installed", String) { |file| options[:name] = file }
  parser.on("--destination=DIR", "Destination directory, where to install package file", String) { |dst| options[:dst] = dst }
  parser.parse(*argv)

  raise ArgumentError.new("action must be specified (build or install)") unless options[:action]
  raise ArgumentError.new("package_file must be specified") if options[:action] == :install and not options[:name]
  raise ArgumentError.new("config file must be specified") if options[:action] == :build and not options[:config]
  raise ArgumentError.new("destination directory must be specified") if options[:action] == :install and not options[:dst]
  options
end

options = parse_options(ARGV)

case options[:action]
when :build
  config = get_options_from_file(File.expand_path(options[:config]))
  SPM::build(config)
when :install
  SPM::install(options[:name], options[:dst])
end
