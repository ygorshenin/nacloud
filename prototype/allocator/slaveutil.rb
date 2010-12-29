#!/usr/bin/ruby
# Author: Yuri Gorshenin

$:.unshift File.expand_path(File.join(File.dirname(__FILE__), '..'))

require 'lib/net/allocator_slave'
require 'lib/options'
require 'lib/res/sysinfo'
require 'optparse'

ACTIONS = [:up, :down, :status]

def parse_options(argv)
  parser, options = OptionParser.new, AllocatorSlave::DEFAULT_OPTIONS
  options[:action] = :up
  
  parser.on("--action=ACTION", "one from #{ACTIONS.join(',')}", "default=#{options[:action]}", ACTIONS) { |action| options[:action] = action }

  parser.on("--id=ID", "id of slave, must be unique", String) { |id| options[:id] = id }
  parser.on("--interface=INTERFACE", "default=#{options[:interface]}", String) { |interface| options[:interface] = interface }
  parser.on("--port=PORT", "port, on which slave will be available by master", "default=#{options[:port]}", Integer) { |port| options[:port] = port }  
  parser.on("--root_dir=DIR", "path to directory with library files", "default=#{options[:root_dir]}", String) { |root_dir| options[:root_dir] = root_dir }
  parser.on("--home_dir=DIR", "name of tasks home directory,", "where all VMDirs will be created", "default=#{options[:home_dir]}", String) { |home_dir| options[:home_dir] = home_dir }
  parser.on("--server_host=HOST", "where is server?", String) { |server_host| options[:server_host] = server_host }
  parser.on("--server_port=PORT", "on which port?", "default=#{options[:server_port]}", String) { |server_port| options[:server_port] = server_port }
  parser.on("--register_timeout=TIME", "timeout between consecutive register tries", "default=#{options[:register_timeout]}", Integer) { |register_timeout| options[:register_timeout] = register_timeout }
  parser.on("--resources=FILE", "file with resources description", String) { |resources| options[:resources] = resources }  
  parser.on("--logfile=FILE", "name of logfile", "default=#{options[:logfile]}", String) { |logfile| options[:logfile] = logfile }

  parser.parse(*argv)

  required = options[:action] == :up ? AllocatorSlave::STRONG_OPTIONS : AllocatorSlave::WEAK_OPTIONS

  required.each do |option|
    raise ArgumentError.new("#{option} must be specified") unless options[option]
  end
  if options[:action] == :up
    options[:resources] = File.expand_path(options[:resources])
    options[:resources] = SysInfo.read_info(options[:resources])
  end
  options
end

begin
  options = parse_options(ARGV)
rescue Exception => e
  STDERR.puts e
  exit -1
end

begin
  DRb.start_service
  uri = "druby://#{options[:interface]}:#{options[:port]}"
  case options[:action]
  when :up
    pid = fork do
      Process::setsid
      STDIN.reopen('/dev/null', 'r')
      STDOUT.reopen('/dev/null', 'w')
      STDERR.reopen('/dev/null', 'w')
      
      slave = AllocatorSlave.new(options)
      slave.up(uri)
    end
    Process::detach pid
  when :down
    begin
      slave = DRbObject.new_with_uri(uri)
      slave.down
    rescue DRb::DRbConnError => e
    end
  when :status
    begin
      slave = DRbObject.new_with_uri(uri)
      puts slave.status
    rescue DRb::DRbConnError => e
      puts "seems that server is down"
    end
  end
rescue Exception => e
  STDERR.puts e
  exit -1
end
