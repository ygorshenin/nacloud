#!/usr/bin/ruby
# Author: Yuri Gorshenin

# This script performs operations on croud of slaves.
# User must specify only configuration file and action (up, down or status).
#
# Configuration file must looks like:
# 
# port: 30000
# base: slave
# ip_addresses:
#   - 173.255.123.52
#   - 173.255.123.53
#   - ...
# server_host: 173.255.123.51
# server_port: 30000
#
# db_host: 173.255.123.51
# db_port: 9160
#
# resources:
#   ram: 4G
#   disk: 100G
#
# it describes slaves with names slave0, slave1 and so on, which will be hosted
# on machines 173.255.123.52, 173.255.123.53, ...

$:.unshift File.join(File.dirname(__FILE__), '..')

require 'optparse'
require 'slave_remote_util'
require 'lib/ext/core_ext'
require 'yaml'

ACTIONS = [:up, :down, :status]

def parse_options(argv)
  options, parser = { :action => :up }, OptionParser.new
  parser.on("--action=ACTION", "one from #{ACTIONS.join(',')}", "default=#{options[:action]}", ACTIONS) { |action| options[:action] = action }
  parser.on("--config=FILE", "YAML configuration file, that contains", "all necessary options", String) { |config| options[:config] = config }
  parser.parse(*argv)

  options
end

class CroudConfigUtils
  DEFAULT_OPTIONS = {
    :base => 'slave',
    :port => SlaveRemoteUtil::DEFAULT_OPTIONS[:port],
    :server_port => SlaveRemoteUtil::DEFAULT_OPTIONS[:server_port],
    :db_port => SlaveRemoteUtil::DEFAULT_OPTIONS[:db_port],
    :addresses => [],
  }
  
  def self.read_config(options)
    return prepare_config(read_content_from_file(options[:config]))
  end

  private

  # only reads content from file
  def self.read_content_from_file(path)
    File.open(path, 'r') do |file|
      return YAML::load(file.read)
    end
  end

  # Prepares jobs configuration file.
  # Modifies config and returns it.
  # Options are not modified.
  def self.prepare_config(config, options = {})
    # Symbolizes all root's keys
    config.keys.each do |key|
      config[key.to_sym] = config.delete(key) unless key.is_a? Symbol
    end
    config = DEFAULT_OPTIONS.merge(config)
    config[:base] = String(config[:base])
    config[:addresses] = Array(config[:addresses] || [])
    return config
  end
end

# This module contains some checks.
# May be useful in constructing config verificator.
module ConfigChecks
  IDENTIFIER_REGEX = /^[a-zA-Z0-9_]+$/

  # Checks slaveses base.
  # Raises exception, if fails.
  def check_slave_base(config)
    raise ArgumentError.new('there is must be slave base name in config') unless config.has_key? :base
    raise ArgumentError.new('base must be an standart identifier') unless config[:base] =~ IDENTIFIER_REGEX
  end

  # Checks slaveses port.
  # Raises exception, if fails.
  def check_slave_port(config)
    raise ArgumentError.new('there are must be slave port in config') unless config.has_key? :port
  end

  # Checks server configuration (host and port).
  # Raises exception, if fails.
  def check_server(config)
    raise ArgumentError.new('there is must be server host in config') unless config.has_key? :server_host
    raise ArgumentError.new('there is must be server host in config') unless config.has_key? :server_port
  end

  # Checks database configuration (host and port).
  # Raises exception, if fails.
  def check_db(config)
    raise ArgumentError.new('there is must be db host in config') unless config.has_key? :db_host
    raise ArgumentError.new('there is must be db port in config') unless config.has_key? :db_port
  end

  # Checks addresses array.
  # Raises exception, if fails.
  def check_addresses(config)
    raise ArgumentError.new('there are must be an array of slaveses hosts in config') unless config.has_key? :addresses
    raise ArgumentError.new('addresses must be an array in config') unless config[:addresses].is_a? Array
  end

  # Checks resources.
  # Raises exception, if fails.
  def check_resources(config)
    raise ArgumentError.new('there are must be an resources segment in config') unless config.has_key? :resources
    raise ArgumentError.new('resources must be an hash in config') unless config.is_a? Hash
  end
end

# Verifies all aspects of config.
class StrongConfigChecker
  include ConfigChecks

  # Methods from ConfigChecks, that used in verification
  METHODS = [:check_slave_base, :check_slave_port, :check_server, :check_db, :check_addresses, :check_resources]

  def check(config)
    METHODS.each { |method| send method, config }
  end
end

# Verifies only port and addresses.
class WeakConfigChecker
  include ConfigChecks

  # Methods from ConfigChecks, that used in verification
  METHODS = [:check_addresses, :check_slave_port]

  def check(config)
    METHODS.each { |method| send method, config }
  end
end

# Class reports info about each host and corresponding status.
class Reporter
  def self.report(addresses, statuses)
    return addresses.zip(statuses).map{|address, status| "#{address}\t: #{status}"}.join("\n")
  end
end

class RemoteSlavesUp
  # Ups remote slaves.
  # Returns string with results for each host
  def do(config)
    resources = gen_tmp_name
    File.open(resources, 'w') { |file| file.write config[:resources].to_yaml }
    result = config[:addresses].process_parallel do |address, index|
      Thread.current[:status] = do_single(config.merge({:host => address, :id => config[:base] + index.to_s, :resources => resources}))
    end
    File.delete resources
    return result
  end

  private

  # Returns :success or :fail
  def do_single(options)
    begin
      SlaveRemoteUtil.new(options).up(:raise_if_fails => true)
      return :success
    rescue Exception => e
      return :fail
    end
  end

  def gen_tmp_name
    return "#{Time.now.to_i}.#{Process.pid}"
  end
end

class RemoteSlavesDown
  def do(config)
    return config[:addresses].process_parallel do |address, index|
      Thread.current[:status] = do_single(config.merge({:host => address}))
    end
  end

  private

  # Returns :success or :fail
  def do_single(options)
    begin
      SlaveRemoteUtil.new(options).down
      return :success
    rescue Exception => e
      return :fail
    end
  end
end

class RemoteSlavesStatus
  def do(config)
    return config[:addresses].process_parallel do |address, index|
      Thread.current[:status] = do_single(config.merge({:host => address}))
    end
  end

  private

  # Returns status or :fail
  def do_single(options)
    begin
      return SlaveRemoteUtil.new(options).status
    rescue Exception => e
      return :fail
    end    
  end
end

begin
  options = parse_options(ARGV)
rescue Exception => e
  STDERR.puts e
  exit -1
end

begin
  config = CroudConfigUtils::read_config(options)
  checker = (options[:action] == :up ? StrongConfigChecker : WeakConfigChecker).new
  checker.check config

  case options[:action]
  when :up then result = RemoteSlavesUp.new.do(config)
  when :down then result = RemoteSlavesDown.new.do(config)
  when :status then result = RemoteSlavesStatus.new.do(config)
  end

  puts Reporter.report(config[:addresses], result)
rescue Exception => e
  STDERR.puts e
  STDERR.puts e.backtrace
  exit -1
end
