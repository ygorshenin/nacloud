#!/usr/bin/ruby
# Author: Yuri Gorshenin

# Uploads and starts job to server
# config file must have following format:
# 
# jobs:
#   - job: "first_job"
#     command: "echo 'hello' > hello.txt"
#     replicas: 10
#
#     options:
#       different_nodes: true
#   - job: "second_job"
#     binary: "/home/ygorhsenin/Coding/Area51/main"
#

$:.unshift File.expand_path(File.join(File.dirname(__FILE__), '..'))

require 'drb'
require 'fileutils'
require 'lib/ext/core_ext'
require 'lib/net/database_system'
require 'lib/options'
require 'lib/package/spm'
require 'optparse'

ACTIONS = [:up, :down]

def get_db_client(server, host)
  port = server.get_db_client_port
  DRbObject.new_with_uri("druby://#{host}:#{port}")
end

def parse_options(argv)
  parser, options = OptionParser.new, { :action => :up }

  parser.on("--action=ACTION", "one from #{ACTIONS.join(',')}", "default=#{options[:action]}", ACTIONS) { |action| options[:action] = action }
  parser.on("--config=FILE", "job configuration file", String) { |config| options[:config] = config }
  parser.on("--host=HOST", "server host", String) { |host| options[:host] = host }
  parser.on("--port=PORT", "server port", Integer) { |port| options[:port] = port }
  parser.on("--user=USER", "user ID", String) { |user| options[:user] = user }
  
  parser.parse(*argv)

  [:config, :host, :port, :user].each do |option|
    raise ArgumentError.new("option '#{option}' must be specified") unless options[option]
  end
  options[:config] = File.expand_path(options[:config])
  options
end

# Returns true if success
def upload_job(server, db_client, packages, job_options)
  begin
    return false if db_client.exists_job?(job_options)
    
    db_client.insert_job(job_options)

    if job_options.has_key?(:binary)
      File.open(job_options[:binary], 'r') { |file| db_client.insert_binary(file.read, job_options) }
    end
    
    if job_options.has_key?(:packages)
      job_options[:packages].each do |package_name|
        SPM::build(packages[package_name])
        File.open(package_name, 'r') { |file| db_client.insert_package(file.read, { :package_name => package_name }.merge(job_options)) }
        FileUtils.rm(package_name)
      end
    end
    return true
  rescue Exception => e
    STDERR.puts e.message
    STDERR.puts e.backtrace
    return false
  end  
end

begin
  options = parse_options(ARGV)
rescue Exception => e
  STDERR.puts e
  exit -1
end

config = get_options_from_file(options[:config])
config[:jobs].map! { |job| { :user => options[:user] }.merge(job.symbolize_keys_recursive!) }

packages = {}
(config[:packages] || []).each do |package|
  package.symbolize_keys_recursive!
  package[:data] ||= []
  package[:data].each { |h| h.symbolize_keys_recursive! }
  packages[package[:name]] = package
end

DRb.start_service
server = DRbObject.new_with_uri("druby://#{options[:host]}:#{options[:port]}")
db_client = get_db_client(server, options[:host])

begin
  case options[:action]
  when :up
    config[:jobs].each do |job_options|
      done = upload_job(server, db_client, packages, job_options) and server.add_job(job_options)
      puts "for job '#{job_options[:name]}': " + (done ? "done" : "fail")
    end
  when :down
    config[:jobs].each do |job_options|
      result = server.kill_job(job_options) ? "done" : "fail"
      puts "for job '#{job_options[:name]}': " + result
    end
  end
rescue Exception => e
  STDERR.puts e.message
  STDERR.puts e.backtrace
end
