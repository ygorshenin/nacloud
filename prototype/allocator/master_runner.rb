#!/usr/bin/ruby
# Author: Yuri Gorshenin

require 'lib/ext/core_ext'
require 'lib/net/allocator_master'
require 'lib/options'
require 'optparse'

ACTIONS = [ :start, :stop ]

def parse_options(argv)
  parser, options = OptionParser.new, AllocatorMaster::DEFAULT_OPTIONS
  options[:action] = :start
  
  parser.on("--logfile=FILE", String) { |logfile| options[:logfile] = logfile }
  parser.on("--action=ACTION", "one from #{ACTIONS.join(',')}", "default=#{options[:action]}", ACTIONS) { |action| options[:action] = action }
  parser.on("--config=FILE", "file, that contains routing table", String) { |config| options[:config] = config }
  parser.on("--host=HOST", "default=#{options[:host]}") { |host| options[:host] = host }
  parser.on("--port=PORT", "port on which server will run", Integer) { |port| options[:port] = port }

  parser.parse(*argv)
  
  [:config, :port].each do |option|
    raise ArgumentError.new("#{option} must be specified") unless options.has_key?(option)
  end

  options
end

begin
  options = parse_options(ARGV)
rescue Exception => e
  STDERR.puts e.message
  exit -1
end

if options[:config]
  # Retrieving options from ARGV
  begin
    router = get_options_from_file(File.expand_path(options.delete(:config)))
    # Adding default entries to config (if not specified)
  rescue Exception => e
    STDERR.puts e.message
    exit -1
  end
end

begin
  uri = "druby://#{options[:host]}:#{options[:port]}"
  case options[:action]
  when :start
    master = AllocatorMaster.new(router, options)
    
    trap ("INT") { master.stop }
    master.start(uri)
  when :stop
    DRb.start_service
    master = DRbObject.new_with_uri(uri)
    master.stop
  end
rescue Exception => e
  STDERR.puts e.message
  exit -1
end
