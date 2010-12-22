#!/usr/bin/ruby
# Author: Yuri Gorshenin

$:.unshift File.expand_path(File.join(File.dirname(__FILE__), '..'))

require 'lib/net/allocator_slave'
require 'lib/options'
require 'lib/res/sysinfo'
require 'optparse'

def parse_options(argv)
  options = AllocatorSlave::DEFAULT_OPTIONS
  
  parser = OptionParser.new
  parser.on("--home_dir=DIR", "name of tasks home directory,", "where all VMDirs will be created", "default=#{options[:home_dir]}", String) { |home_dir| options[:home_dir] = home_dir }
  parser.on("--host=HOST", "host, on which slave must be runned", "default=#{options[:host]}", String) { |host| options[:host] = host }
  parser.on("--id=ID", "id of slave, must be unique", String) { |id| options[:id] = id }
  parser.on("--logfile=FILE", "name of logfile", String) { |logfile| options[:logfile] = logfile }
  parser.on("--port=PORT", "port, on which slave will be available", "by master", Integer) { |port| options[:port] = port }
  parser.on("--register_timeout=TIME", "timeout between consecutive", "connection times", "default=#{options[:register_timeout]}", Integer) { |register_timeout| options[:register_timeout] = register_timeout }
  parser.on("--root_dir=DIR", "path to directory with library files", "default=#{options[:root_dir]}", String) { |root_dir| options[:root_dir] = root_dir }
  parser.on("--server_host=HOST", "where is server?", String) { |server_host| options[:server_host] = server_host }
  parser.on("--server_port=PORT", "on which port?", String) { |server_port| options[:server_port] = server_port }
  parser.on("--resources=FILE", "file with resources description", String) { |resources| options[:resources] = resources }

  parser.parse(*argv)

  AllocatorSlave::REQUIRED_OPTIONS.each do |option|
    raise ArgumentError.new("#{option} must be specified") unless options[option]
  end
  options[:resources] = File.expand_path(options[:resources])
  options[:resources] = SysInfo.read_info(options[:resources])
  options
end

begin
  options = parse_options(ARGV)
rescue Exception => e
  STDERR.puts e
  exit -1
end

begin
  slave = AllocatorSlave.new(options)
  uri = "druby://#{`hostname`.strip}:#{options[:port]}"
  trap ('INT') { slave.stop }
  slave.start(uri)
rescue ArgumentError => e
  STDERR.puts e.message
  exit -1
rescue Exception => e
  STDERR.puts e
  exit -1
end
