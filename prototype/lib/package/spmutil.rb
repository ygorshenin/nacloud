#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'lib/package/spm'
require 'optparse'
require 'yaml'

def parse_options(argv)
  parser, options = OptionParser.new, {}
  parser.on("-b", "--build") { options[:action] = :build }
  parser.on("-i", "--install") { options[:action] = :install }
  parser.on("--config_file=FILE", "YAML configuration file that specifies package structure", String) { |file| options[:config] = file }
  parser.on("--package_file=FILE", "SPM file, that will be created or installed", String) { |file| options[:name] = file }
  parser.parse(*argv)

  raise ArgumentError.new("action must be specified (build or install)") unless options[:action]
  raise ArgumentError.new("package_file must be specified") unless options[:name]
  raise ArgumentError.new("config file must be specified") if options[:action] == :build and not options[:config]
  options
end

options = parse_options(ARGV)

case options[:action]
when :build
  config = YAML::load(File.open(File.expand_path(options[:config]), 'r'))
  SPM::build(config, options[:name], :verbose => true)
  
when :install
  raise RuntimeError.new('Method not implemented yet')
end
