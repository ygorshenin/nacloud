#!/usr/bin/ruby
# Author: Yuri Gorshenin

$:.unshift File.expand_path(File.join(File.dirname(__FILE__), '..'))

require 'lib/ext/core_ext'
require 'lib/net/allocator_master'
require 'lib/options'
require 'optparse'

ACTIONS = [:up, :down, :status]

def parse_options(argv)
  parser, options = OptionParser.new, AllocatorMaster::DEFAULT_OPTIONS
  options[:action] = :up

  parser.on("--action=ACTION", "one from #{ACTIONS.join(',')}", "default=#{options[:action]}", ACTIONS) { |action| options[:action] = action }
  parser.on("--db_host=HOST", "database host", "default=#{options[:db_host]}", String) { |db_host| options[:db_host] = db_host }
  parser.on("--db_port=PORT", "database port", "default=#{options[:db_port]}", Integer) { |db_port| options[:db_port] = db_port }
  parser.on("--db_client_port=PORT", "database client port", "default=#{options[:db_client_port]}", Integer) { |db_client_port| options[:db_client_port] = db_client_port }
  parser.on("--interface=INTERFACE", "default=#{options[:interface]}", String) { |host| options[:interface] = host }
  parser.on("--logfile=FILE", "default=#{options[:logfile]}", String) { |logfile| options[:logfile] = logfile }
  parser.on("--port=PORT", "port on which server will run", "default=#{options[:port]}", Integer) { |port| options[:port] = port }

  parser.parse(*argv)

  required = (options[:action] == :up ? AllocatorMaster::STRONG_OPTIONS : AllocatorMaster::WEAK_OPTIONS)
  
  required.each do |option|
    raise ArgumentError.new("#{option} must be specified") unless options.has_key?(option)
  end
  return options
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
      
      master = AllocatorMaster.new(options)
      master.up(uri)
    end
    Process::detach pid
  when :down
    begin
      master = DRbObject.new_with_uri(uri)
      master.down
    rescue DRb::DRbConnError => e
    end
  when :status
    begin
      master = DRbObject.new_with_uri(uri)
      puts master.status
    rescue DRb::DRbConnError => e
      puts "seems that server is down"
    end
  end
rescue Exception => e
  STDERR.puts e
  exit -1
end
