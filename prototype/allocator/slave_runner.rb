#!/usr/bin/ruby
# Author: Yuri Gorshenin

require 'lib/net/allocator_slave'
require 'optparse'

def parse_options(argv)
  options = {
    :port => 31338,
    :root_dir => 'slave',
    :home_dir => 'home',
  }
  parser = OptionParser.new
  parser.on("--port=PORT", "default value: #{options[:port]}", Integer) { |port| options[:port] = port }
  parser.on("--root_dir=DIR", "default value: #{options[:root_dir]}", String) { |root_dir| options[:root_dir] = root_dir }
  parser.on("--home_dir=DIR", "default value: #{options[:home_dir]}", String) { |home_dir| options[:home_dir] = home_dir }
  parser.on("--logfile=FILE", String) { |logfile| options[:logfile] = logfile }

  parser.parse(*argv)

  options
end

options = parse_options(ARGV)
slave = AllocatorSlave.new(options)
uri = "druby://localhost:#{options[:port]}"
DRb.start_service(uri, slave)
STDERR.puts "slave started on #{uri}, PID: #{Process.pid}"
DRb.thread.join
