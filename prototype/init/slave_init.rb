#!/usr/bin/ruby

# Author: Yuri Gorshenin

# This script connects to Cassandra's database server, checks and
# downloads latest version of slave.  User only must specify database
# host, port and destination, where to put downloaded files.
# 
# Script is designed to be runned without other parts of system.

require 'cassandra'
require 'digest'
require 'optparse'

KEYSPACE = 'Storage'
COLUMN_FAMILY = :NodeLib

# Parses and checks options.
# argv is an array with options.
# Throws exception, if fails.
def parse_options(argv)
  options, parser = { :dst => '.' }, OptionParser.new

  parser.on('-h', '--host', "Cassandra's host", String) { |host| options[:host] = host }
  parser.on('-p', '--port', "Cassandra's port", Integer) { |port| options[:port] = port }
  parser.on('-d', '--dst', "where to put all packages", "default=.", String) { |dst| options[:dst] = dst }

  parser.parse(*argv)
  check_options(options)

  options
end

# Tries to check options.
# Throws exception, if fails.
def check_options(options)
  options[:dst] = File.expand_path(options[:dst])
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
  raise RuntimeError.new("here are no 'latest' column in '#{COLUMN_FAMILY}'") unless client.exists?(COLUMN_FAMILY, 'latest')
  id = client.get(COLUMN_FAMILY, 'latest')
  raise RuntimeError.new("here are no #{id} row in '#{COLUMN_FAMILY}'") unless client.exists?(:NodeLib, id)
  record = client.get(COLUMN_FAMILY, id)
  raise RuntimeError.new("there must be single column, but here are #{record.size} column(s)") if hash.size != 1
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
