#!/usr/bin/ruby
# Author: Yuri Gorshenin

require 'lib/net/allocator_slave'
require 'optparse'

def parse_options(argv)
  options = AllocatorSlave::DEFAULT_OPTIONS
  
  parser = OptionParser.new
  parser.on("--id=ID", String) { |id| options[:id] = id }
  parser.on("--host=HOST", "default=#{options[:host]}", String) { |host| options[:host] = host }
  parser.on("--port=PORT", Integer) { |port| options[:port] = port }
  parser.on("--root_dir=DIR", "default=#{options[:root_dir]}", String) { |root_dir| options[:root_dir] = root_dir }
  parser.on("--home_dir=DIR", "default=#{options[:home_dir]}", String) { |home_dir| options[:home_dir] = home_dir }
  parser.on("--server_host=HOST", String) { |server_host| options[:server_host] = server_host }
  parser.on("--server_port=PORT", String) { |server_port| options[:server_port] = server_port }
  parser.on("--update_timeout=TIME", "default=#{options[:update_timeout]}", Integer) { |update_timeout| options[:update_timeout] = update_timeout }
  parser.on("--logfile=FILE", String) { |logfile| options[:logfile] = logfile }

  parser.parse(*argv)

  AllocatorSlave::REQUIRED_OPTIONS.each do |option|
    raise ArgumentError.new("#{option} must be specified") unless options[option]
  end
  options
end

begin
  options = parse_options(ARGV)
  slave = AllocatorSlave.new(options)
  uri = "druby://#{`hostname`.strip}:#{options[:port]}"
  trap ("INT") { slave.stop }
  slave.start(uri)
rescue Exception => e
  STDERR.puts e.message
  exit -1
end
