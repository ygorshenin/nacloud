#!/usr/bin/ruby
# Author: Yuri Gorshenin

# This script connects to Cassandra's database server, checks and
# downloads latest version of slave.  User only must specify database
# host, port and destination, where to put downloaded files.
# 
# Script is designed to be runned without other parts of system.

$:.unshift File.expand_path(File.dirname(__FILE__))

require 'rubygems'

require 'cassandra'
require 'digest'
require 'fileutils'
require 'optparse'
require 'slave_core'

include SlaveCore

# Parses and checks options.
# argv is an array with options.
# Throws exception, if fails.
def parse_options(argv)
  options, parser = { :dst => '.' }, OptionParser.new

  parser.on('-h', '--host=HOST', "Cassandra's host", String) { |host| options[:host] = host }
  parser.on('-p', '--port=PORT', "Cassandra's port", Integer) { |port| options[:port] = port }
  parser.on('-d', '--dst=DIR', "where to put all packages", "default=.", String) { |dst| options[:dst] = dst }

  parser.parse(*argv)
  options[:dst] = File.expand_path(options[:dst])
  check_options(options)
  options
end

# Tries to check options.
# Throws exception, if fails.
def check_options(options)
  [:host, :port].each { |option| raise ArgumentError.new("option '#{option}' must be specified") unless options.has_key? option }
end

# Creates all needed directories
def make_infrastructure(options)
  FileUtils.mkdir_p(options[:dst])
end

# Downloads and checks package from database (by client) into options[:dst] directory.
# Raises error, if fails.
# Returns path to downloaded package
def download_package(client, options)
  id = client.get(COLUMN_FAMILY, LATEST)
  raise RuntimeError.new("here are no '#{LATEST}' column in '#{COLUMN_FAMILY}'") unless id and id[LATEST]
  id = id[LATEST]
  record = client.get(COLUMN_FAMILY, id)
  raise RuntimeError.new("here are no #{id} row in '#{COLUMN_FAMILY}'") unless record
  raise RuntimeError.new("there must be single column, but here are #{record.size} column(s)") if record.size != 1
  name = record.keys.first # reads package hash
  data = record[name]
  raise RuntimeError.new("checksums did not match") unless name == Digest::MD5.hexdigest(data)
  path = File.join(options[:dst], name)
  File.open(path, 'w') { |file| file.write(record[name]) }
  return path
end

def install_package(path)
  dir, name = File.dirname(path), File.basename(path)
  `cd #{dir}; tar -xzf #{name}; rm #{name}`
end

options = parse_options(ARGV)
make_infrastructure(options)
client = Cassandra.new(KEYSPACE, "#{options[:host]}:#{options[:port]}")
install_package(download_package(client, options))
