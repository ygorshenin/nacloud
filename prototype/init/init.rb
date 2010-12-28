#!/usr/bin/ruby
# Author: Yuri Gorshenin

$:.unshift File.dirname(__FILE__)

require 'optparse'
require 'slave_remote_util'

ACTIONS = [ :up, :down, :status ]

def parse_options(argv)
  options, parser = SlaveRemoteUtil::DEFAULT_OPTIONS, OptionParser.new
  options[:action] = :up

  # General options
  parser.on("--action=ACTION", "one action from: #{ACTIONS.join(',')}", "default=#{options[:action]}", ACTIONS) { |action| options[:action] = action }
  parser.on('--host=HOST', "host, on which slave will be installed", String) { |host| options[:host] = host }
  parser.on('--user=USER', "user, which login will be used", "default=#{options[:user]}", String) { |user| options[:user] = user }
  parser.on('--identity=FILE', "ssh identity file", "default=#{options[:identity]}", String) { |identity| options[:identity] = identity }
  parser.on('--dst=DIR', "where to put slave file", "default=#{options[:dst]}", String) { |dst| options[:dst] = dst }
  # Slave specified options
  parser.on("--db_host=HOST", "Cassandra's host", String) { |db_host| options[:db_host] = db_host }
  parser.on("--db_port=PORT", "Cassandra's port", String) { |db_port| options[:db_port] = db_port }
  parser.on("--id=ID", "id of slave, must be unique", String) { |id| options[:id] = id }
  parser.on("--logfile=FILE", "name of logfile", String) { |logfile| options[:logfile] = logfile }
  parser.on("--port=PORT", "port, on which slave will be available", "by master", Integer) { |port| options[:port] = port }
  parser.on("--server_host=HOST", "where is server?", String) { |server_host| options[:server_host] = server_host }
  parser.on("--server_port=PORT", "on which port?", String) { |server_port| options[:server_port] = server_port }
  parser.on("--resources=FILE", "local file with resources description", String) { |resources| options[:resources] = resources }

  parser.parse(*argv)

  required = (options[:action] == :up ? SlaveRemoteUtil::STRONG_OPTIONS : SlaveRemoteUtil::WEAK_OPTIONS)

  required.each do |option|
    raise ArgumentError.new("#{option} must be specified") unless options[option]
  end
  
  options[:identity] = File.expand_path(options[:identity]) if options.has_key? :identity
  options[:resources] = File.expand_path(options[:resources]) if options.has_key? :resources
  return options
end

begin
  options = parse_options(ARGV)
rescue Exception => e
  STDERR.puts e
  exit -1
end

begin
  util = SlaveRemoteUtil.new(options)
  case options[:action]
  when :up then util.up(:raise_if_fails => true)
  when :down then util.down
  when :status then puts util.status
  end
rescue Exception => e
  STDERR.puts e
  STDERR.puts e.backtrace
  exit -1
end
