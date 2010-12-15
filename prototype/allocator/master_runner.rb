#!/usr/bin/ruby
# Author: Yuri Gorshenin

require 'lib/ext/core_ext'
require 'lib/net/allocator_master'
require 'lib/options'
require 'optparse'

ACTIONS = [:start, :stop]

def parse_options(argv)
  parser, options = OptionParser.new, AllocatorMaster::DEFAULT_OPTIONS
  options[:action] = :start

  parser.on("--allocator_timeout=TIME", "default=#{options[:allocator_timeout]}", Integer) { |allocator_timeout| options[:allocator_timeout] = allocator_timeout }
  parser.on("--job_timeout=TIME", "default=#{options[:job_timeout]}", Integer) { |job_timeout| options[:job_timeout] = job_timeout }
  parser.on("--action=ACTION", "one from #{ACTIONS.join(',')}", "default=#{options[:action]}", ACTIONS) { |action| options[:action] = action }
  parser.on("--db_host=HOST", "database host", String) { |db_host| options[:db_host] = db_host }
  parser.on("--db_port=PORT", "database port", Integer) { |db_port| options[:db_port] = db_port }
  parser.on("--db_client_port=PORT", "database client port", Integer) { |db_client_port| options[:db_client_port] = db_client_port }
  parser.on("--host=HOST", "default=#{options[:host]}") { |host| options[:host] = host }
  parser.on("--logfile=FILE", String) { |logfile| options[:logfile] = logfile }
  parser.on("--port=PORT", "port on which server will run", Integer) { |port| options[:port] = port }

  parser.parse(*argv)

  required = [:port]
  required += [:db_host, :db_port, :db_client_port] if options[:action] == :start
  
  required.each do |option|
    raise ArgumentError.new("#{option} must be specified") unless options.has_key?(option)
  end

  options
end

begin
  options = parse_options(ARGV)
rescue ArgumentError => e
  STDERR.puts e.message
  exit -1
rescue Exception => e
  STDERR.puts e
  exit -1
end

begin
  uri = "druby://#{options[:host]}:#{options[:port]}"
  case options[:action]
  when :start
    master = AllocatorMaster.new(options)
    trap ('INT') { master.stop }
    master.start(uri)
  when :stop
    DRb.start_service
    master = DRbObject.new_with_uri(uri)
    master.stop
  end
rescue Exception => e
  STDERR.puts e
  exit -1
end
