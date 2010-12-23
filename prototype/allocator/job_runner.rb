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

# Parses script options from argv.
# Raises ArgumentError, if important options are missed.
# Returns parsed options as Hash.
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

  # Ruby doesn't understand ~ abbrevs, so it's better to manually expand path
  options[:config] = File.expand_path(options[:config])
  options
end

# Basic configuration utils.
# Allows user to read job's configuration file,
# with automatically completed fields, or complete
# existing config.
class ConfigUtils
  # Default resources values
  DEFAULT_RESOURCES = {
    :ram => 64, # in Mb
  }
  
  # Reads and prepares configuration file from options[:config]
  def self.read_config(options)
    prepare_config(get_options_from_file(options[:config]), options)
  end
  
  # Prepares jobs configuration file.
  # Modifies config and returns it.
  # Options are not modified.
  def self.prepare_config(config, options = {})
    # There always must be :jobs and :packages keys
    config[:jobs] = Array(config[:jobs] || [])
    prepare_jobs(config[:jobs], options)
    config[:packages] = Array(config[:packages] || [])
    prepare_packages(config[:packages], options)
    config
  end

  private

  # Prepares one package description.
  # Modifies argument and returns it.
  def self.prepare_package(package, options = {})
    package.symbolize_keys_recursive! # Symbolize all keys in package description
    package[:name] = String(package[:name]) if package.has_key? :name
    package[:data] = Array(package[:data] || []) # Makes :data value array
    package[:data].each { |h| h.symbolize_keys_recursive! } # Symbolize all :data keys
    package[:data].each do |h|
      if h.has_key? :source
        h[:source] = File.expand_path(String(h[:source]))
      end
      h[:target] = String(h[:target]) if h.has_key? :target
    end
    package
  end

  # Prepares packages description.
  # Packages must be an array of descriptions.
  # Modifies argument and returns it.
  def self.prepare_packages(packages, options = {})
    packages.each { |package| prepare_package(package, options) }
    packages
  end

  # Prepares job options.
  # Modifies argument and returns it.
  def self.prepare_job(job, options = {})
    job.symbolize_keys_recursive! # Symbolize all keys in that Hash
    job[:name] = String(job[:name]) if job.has_key? :name
    job[:user] = String(job[:user] || options[:user]) # If nothing are presented (nil), empty string
    job[:packages] = Array(job[:packages] || []) # job[:packages] must be array
    job[:replicas] ||= 1
    job[:options] ||= {} # job[:options] always must be
    job[:options][:different_nodes] ||= false # By default different nodes is not necessary

    if job.has_key? :binary
      job[:binary] = File.expand_path(String(job[:binary]))
    end

    job[:command] = String(job[:command]) if job.has_key? :command

    job[:resources] ||= {}
    job[:resources] = job[:resources].merge(DEFAULT_RESOURCES)
    job[:resources][:ram] = job[:resources][:ram].to_i
  end

  # Prepares jobs description.
  # Jobs must be an array of descriptions.
  # Modifies argument and returns it.
  def self.prepare_jobs(jobs, options = {})
    jobs.each { |job| prepare_job(job, options) }
    jobs
  end
end

# This module contains some checks.
# May be useful in constructing config verificator.
module JobChecks
  IDENTIFIER_REGEX = /^[a-zA-Z0-9_]+$/
  
  # Only checks job name.
  # Raises exception, if fails.
  def check_job_name(job)
    raise ArgumentError.new('job must have a name') unless job.has_key? :name
    raise ArgumentError.new("for job '#{job[:name]}': name must be an standart identifier") unless job[:name] =~ IDENTIFIER_REGEX
  end

  # Checks user key and user value format.
  # Raises exception, if fails.
  def check_job_user(job)
    raise ArgumentError.new('job must have a user') unless job.has_key? :user
    raise ArgumentError.new("for job '#{job[:name]}': user must be an standart identifier") unless job[:user] =~ IDENTIFIER_REGEX
  end

  # Checks resources (must be Numeric, non-negative etc.)
  # Raises exception, if fails.
  def check_job_resources(job)
    raise ArgumentError("for job '#{job[:name]}': ram must be a number") unless job[:resources][:ram].is_a?(Numeric)
    raise ArgumentError("for job '#{job[:name]}': ram usage must be >= 0") unless job[:resources][:ram] >= 0
  end

  # Checks that all packages used by this job are exists.
  # Raises exception, if fails.
  def check_job_packages(job, packages)
    job[:packages].each do |package|
      raise ArgumentError.new("for job '#{job[:name]}': package #{package} not found") unless packages.has_key? package
    end
  end

  # Checks job's description for consistensy.
  # Doesn't checks job's dependencies.
  # Raises exception, if fails.
  def check_job(job)
    check_job_name(job)
    check_job_user(job)
    check_job_resources(job)
    
    if not job[:replicas].is_a?(Fixnum) or job[:replicas] < 1
      raise ArgumentError.new("for job '#{job[:name]}': replicas must be a fixnum >= 1")
    end
    
    different_nodes = job[:options][:different_nodes]
    if not different_nodes.is_a?(TrueClass) and not different_nodes.is_a?(FalseClass)
      raise ArgumentError.new("for job '#{job[:name]}': different_nodes option must be a bool value")
    end

    if job.has_key?(:binary) and not File::exists?(job[:binary])
      raise ArgumentError.new("for job'#{job[:name]}': binary '#{job[:binary]}' doesn't exists")
    end
  end

  # Checks jobs descriptions for consistensy.
  # Raises exception, if fails.
  def check_jobs(jobs)
    job_names = Set.new
    jobs.each do |job|
      check_job job
      raise ArgumentError.new("duplicate job name: '#{job[:name]}'") if job_names.include? job[:name]
      job_names.add job[:name]
    end
  end

  # Checks package's description for consistency.
  # Raises exception, if fails.
  def check_package(package)
    raise ArgumentError.new("package must have a name") unless package.has_key? :name
    raise ArgumentError.new("for package '#{package[:name]}': name must be an standart identifier") unless package[:name] =~ IDENTIFIER_REGEX
    package[:data].each do |h|
      if h.has_key? :source
        raise ArgumentError.new("for package '#{package[:name]}': source '#{h[:source]}' doesn't exists") unless File::exists? h[:source]
        raise ArgumentError.new("for package '#{package[:name]}': for source  '#{h[:source]}' there must be an target") unless h.has_key? :target
      end
    end
  end

  # Checks packages descriptions for consistency.
  # Raises exception, if fails.
  def check_packages(packages)
    package_names = Set.new
    packages.each do |package|
      check_package package
      raise ArgumentError.new("duplicate package name: '#{package[:name]}'") if package_names.include? package[:name]
      package_names.add package[:name]
    end
  end

  # Checks jobs dependencies (i.e. all used packages)
  def check_dependencies(jobs, packages)
    h = {}
    packages.each { |package| h[package[:name]] = package }
    jobs.each { |job| check_job_packages(job, h) }
  end
end

# Strong Configuration File verificator.
# Must verify all aspects of job configuration file,
# i.e. jobs, users, packages, dependencies etc.
class StrongConfigChecker
  def check(config)
    check_jobs config[:jobs]
    check_packages config[:packages]
    check_dependencies(config[:jobs], config[:packages])    
  end
  
  private
  include JobChecks
end

# Weak Configuration File verificator.
# Verifies only job names and users.
class WeakConfigChecker
  # Checks configuration file.
  # Checks only jobs names.
  def check(config)
    config[:jobs].each do |job|
      check_job_name job
      check_job_user job
    end
  end

  private
  include JobChecks
end

# Uploads job into server, using database client.
# Returns pair [success, message]
def upload_job(server, db_client, packages, job)
  begin
    return [false, "job '#{job[:name]}' already exists"] if db_client.exists_job?(job)
    
    db_client.insert_job(job)
    
    if job.has_key?(:binary)
      File.open(job[:binary], 'r') { |file| db_client.insert_binary(file.read, job_options) }
    end
    
    job[:packages].each do |package|
      SPM::build(packages[package])
      File.open(package, 'r') { |file| db_client.insert_package(file.read, { :package_name => package }.merge(job)) }
      FileUtils.rm(package)
    end
    return [true, 'success']
    
  rescue Exception => e
    return [false, e.message]
  end
end

begin
  options = parse_options(ARGV)
rescue Exception => e
  STDERR.puts e
  STDERR.puts e.backtrace
  exit -1
end

begin
  config = ConfigUtils::read_config(options)
  checker = (options[:action] == :up ? StrongConfigChecker : WeakConfigChecker).new
  checker.check(config)
  
  packages = {}
  config[:packages].each { |package| packages[package[:name]] = package }

  DRb.start_service
  server = DRbObject.new_with_uri("druby://#{options[:host]}:#{options[:port]}")
  db_client = get_db_client(server, options[:host])

  case options[:action]
  when :up then action = lambda do |job|
      result = upload_job(server, db_client, packages, job)
      if not result.first
        db_client.delete_job(job)
        result.second
      else
        result = server.up_job(job)
        if not result.first
          server.down_job(job)
        end
        result.second
      end
    end
    
  when :down then action = lambda { |job| server.down_job(job).second }
  end
  config[:jobs].each { |job| STDERR.puts "\nfor job '#{job[:name]}':\n#{action[job]}" }
rescue Exception => e
  STDERR.puts e
  STDERR.puts e.backtrace
  exit -1
end
