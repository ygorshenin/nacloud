#!/usr/bin/ruby
# Author: Yuri Gorshenin

require 'lib/ext/core_ext'
require 'lib/net/allocator_master'
require 'lib/options'
require 'optparse'

def parse_options(argv)
  parser, options = OptionParser.new, AllocatorMaster::DEFAULT_OPTIONS
  
  parser.on("--logfile=FILE", String) { |logfile| options[:logfile] = logfile }
  parser.on("-c", "--config=FILE", "configuration file, that contains",
            "slaves description and routing table", String) { |config| options[:config] = config }
  parser.on("-h", "--host=HOST", "default=#{options[:host]}") { |host| options[:host] = host }
  parser.on("-p", "--port=PORT", "port on which server will run", Integer) { |port| options[:port] = port }
  
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

begin
  master = AllocatorMaster.new(config[:slaves], config[:router], options)
  
  trap ("INT") { master.stop }
  master.start("druby://#{options[:host]}:#{options[:port]}")
rescue Exception => e
  STDERR.puts e.message
  exit -1
end
