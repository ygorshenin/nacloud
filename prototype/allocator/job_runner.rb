#!/usr/bin/ruby

require 'drb'
require 'fileutils'
require 'lib/ext/core_ext'
require 'lib/options'
require 'lib/package/spm'
require 'optparse'

def parse_options(argv)
  parser, options = OptionParser.new, { :timeout => 3.seconds, :reruns => 3}

  parser.on("-h", "--host=HOST", String) { |host| options[:host] = host }
  parser.on("-p", "--port=PORT", Integer) { |port| options[:port] = port }
  parser.on("-c", "--config=FILE", "job configuration file", String) { |config| options[:config] = config }
  parser.on("-u", "--user=USER", "user ID, which used in job package routing", String) { |user| options[:user_id] = user }
  parser.on("-t", "--timeout=SEC", "timeout in seconds, between consecutive connection tries",
            "default=#{options[:timeout]}", Float) { |timeout| options[:timeout] = timeout }
  parser.on("-r", "--reruns=TIMES", "how many times try to connect to server",
            "default=#{options[:reruns]}", Integer) { |reruns| options[:reruns] = reruns }
  
  parser.parse(*argv)

  [ :host, :port, :config, :user_id ].each do |option|
    raise ArgumentError.new("option '#{option}' must be specified") unless options[option]
  end
  options
end

def get_tmp_name
  "tmp_#{Time.now.to_i}_#{Process.pid}"
end

def upload_job(options)
  config = get_options_from_file(File.expand_path(options[:config]))
  name = get_tmp_name
  uri = "druby://#{options[:host]}:#{options[:port]}"

  STDERR.puts "creating package from job..."
  SPM::build(config, name)
  
  package = ''
  STDERR.puts "loading package into memory..."
  File.open(name, 'r') { |file| package = file.read }
  
  STDERR.puts "removing package file..."
  FileUtils.rm(name)

  done = false
  options[:reruns].times do |effort|
    begin
      STDERR.puts "tries to connect to server..."
      server = DRbObject.new nil, uri
      done = server.run_binary(options[:user_id], package, config[:job])
      STDERR.puts(done ? "ok" : "fails")
    rescue Exception => e
      STDERR.puts e.message
      done = false
    end
    break if done
    sleep options[:timeout]
  end
end

begin
  upload_job(parse_options(ARGV))
rescue Exception => e
  STDERR.puts e.message
  exit -1
end

  
