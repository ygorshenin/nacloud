#!/usr/bin/ruby
# Author: Yuri Gorshenin

require 'lib/ext/core_ext'
require 'lib/net/allocator_master'
require 'lib/options'
require 'optparse'

ACTIONS = [:deploy, :start, :stop]

def parse_options(argv)
  parser, options = OptionParser.new, AllocatorMaster::DEFAULT_OPTIONS
  options[:action] = :start
  
  parser.on("--logfile=FILE", String) { |logfile| options[:logfile] = logfile }
  parser.on("--config=FILE", "configuration file, that contains",
            "slaves description and routing table", String) { |config| options[:config] = config }
  parser.on("-h", "--host=HOST", "local hostname",
            "default=#{options[:host]}", String) { |host| options[:host] = host }
  parser.on("-p", "--port=PORT", "port on which server will run", Integer) { |port| options[:port] = port }
  
  parser.on("--root_dir=DIR", "server root directory",
            "default=#{options[:root_dir]}", String) { |root_dir| options[:root_dir] = root_dir }
  
  parser.on("--slave_runner=RUNNER", "relative path to slave runner script",
            "default=#{options[:slave_runner]}", String) { |slave_runner| options[:slave_runner] = slave_runner }
  
  parser.on("--slave_reruns=TIMES", "how many times rerun slaves",
            "default=#{options[:slave_reruns]}", Integer) { |slave_reruns| options[:slave_reruns] = slave_reruns }

  parser.on("--action=ACTION", ACTIONS, "available actions: #{ACTIONS.join(',')}",
            "default=start") { |action| options[:action] = action }
  
  parser.parse(*argv)
  raise ArgumentError.new("config file must be specified") unless options[:config]
  raise ArgumentError.new("port must be specified") unless options[:port]
  options
end

# Retrieving options from ARGV
begin
  options = parse_options(ARGV)
  config = get_options_from_file(File.expand_path(options.delete(:config)))
rescue Exception => e
  STDERR.puts e.message
  exit -1
end

# Adding default entries to config (if not specified)
config[:slaves] ||= []
config[:slaves].each { |slave| slave.symbolize_keys_recursive! }
config[:router] ||= []
router = config[:router]

# Stringify router keys, because they are Symbols now (after symbolize_keys_recursive! call)
router.each_key do |key|
  value = router.delete(key)
  router[key.to_s] = value
end

uri = "druby://#{options[:host]}:#{options[:port]}"

begin
  DRb.start_service
  if options[:action] == :start # We must start new service
    master = AllocatorMaster.new(config[:slaves], config[:router], options)
  else # We must connect to existing service
    master = DRbObject.new_with_uri(uri)
  end

  case options[:action]
  when :deploy
    master.deploy
  when :start
    master.start(uri)
  when :stop
    master.stop
  end
rescue Exception => e
  STDERR.puts e.message
  exit -1
end
