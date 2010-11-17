#!/usr/bin/ruby
# Author: Yuri Gorshenin

require 'lib/net/allocator_slave'
require 'optparse'

def parse_options(argv)
  options = {
    :port => 31338,
    :work_dir => 'work',
  }
  parser = OptionParser.new
  parser.on("--port=PORT", "default value: #{options[:port]}", Integer) { |port| options[:port] = port }
  parser.on("--work_dir=DIR", "default value: #{options[:work_dir]}", String) { |work_dir| options[:work_dir] = work_dir }
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
