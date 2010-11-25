#!/usr/bin/ruby
# Author: Yuri Gorshenin

require 'lib/ext/core_ext'
require 'lib/net/allocator_master'
require 'lib/options'
require 'optparse'

def parse_options(argv)
  parser, options = OptionParser.new, AllocatorMaster::DEFAULT_OPTIONS
  
  parser.on("--logfile=FILE", String) { |logfile| options[:logfile] = logfile }
  parser.on("--config=FILE", "configuration file, that contains",
            "slaves description and routing table", String) { |config| options[:config] = config }
  parser.on("-h", "--host=HOST", "local hostname", String) { |host| options[:host] = host }
  parser.on("-p", "--port=PORT", "port on which server will run", Integer) { |port| options[:port] = port }
  
  parser.on("--root_dir=DIR", "server root directory",
            "default=#{options[:root_dir]}", String) { |root_dir| options[:root_dir] = root_dir }
  
  parser.on("--slave_runner=RUNNER", "relative path to slave runner script",
            "default=#{options[:slave_runner]}", String) { |slave_runner| options[:slave_runner] = slave_runner }
  
  parser.on("--slave_reruns=TIMES", "how many times rerun slaves",
            "default=#{options[:slave_reruns]}", Integer) { |slave_reruns| options[:slave_reruns] = slave_reruns }
  
  parser.parse(*argv)
  raise ArgumentError.new("config file must be specified") unless options[:config]
  raise ArgumentError.new("port must be specified") unless options[:port]
  options
end

options = parse_options(ARGV)
config = get_options_from_file(File.expand_path(options.delete(:config)))

config[:slaves] ||= []
config[:slaves].each { |slave| slave.symbolize_keys_recursive! }
config[:router] ||= []
router = config[:router]
router.each_key do |key|
  value = router.delete(key)
  router[key.to_s] = value
end

master = AllocatorMaster.new(config[:slaves], config[:router], options)
master.run_slaves

DRb.start_service "druby://#{options[:host]}:#{options[:port]}", master
DRb.thread.join
