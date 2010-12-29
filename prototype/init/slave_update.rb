#!/usr/bin/ruby

# Author: Yuri Gorshenin

# This script connects to Cassandra's database server and
# uploads new version of slave.
# User only must specify database host, port and source directory, from
# which new files will be fetched.
#
# Script is designed to be runned without other parts of system.

$:.unshift File.expand_path(File.dirname(__FILE__))

require 'rubygems'
require 'cassandra'
require 'slave_core'
require 'digest'
require 'optparse'

include SlaveCore

# Parses and check_options options.
# argv is an array with options.
# Throws exception, if fails.
def parse_options(argv)
  options, parser = { :src => '.', :port => 9160 }, OptionParser.new

  parser.on('-h', '--host=HOST', "Cassandra's host", String) { |host| options[:host] = host }
  parser.on('-p', '--port=PORT', "Cassandra's port", "default=#{options[:port]}", Integer) { |port| options[:port] = port }
  parser.on('-s', '--src=DIR', "where to get all packages", "default=.", String) { |src| options[:src] = src }

  options[:src] = File.expand_path(options[:src])
  parser.parse(*argv)
  check_options(options)
  
  options
end

# Tries to check options
# Throws exception, if fails.
def check_options(options)
  [:host, :port].each { |option| raise ArgumentError.new("option '#{option}' must be specified") unless options.has_key? option }
end

# Gets temprorary name for new archive
def get_tmp_name
  "tmp.#{Time.now.to_i}.#{Process::pid}"
end

# Builds package by option[:src]. Doesn't check correctness of this options.
# Returns package data.
def build_package(options)
  Dir.chdir(options[:src])
  archive = get_tmp_name
  `tar -czf #{archive} *`
  file = File.open(archive, 'r')
  data = file.read
  file.close
  File.delete(archive)
  data
end

# Uploads data into database (by client).
def upload_package(client, data)
  id = Time.now.to_s
  cksum = Digest::MD5::hexdigest(data)
  client.insert(COLUMN_FAMILY, id, { cksum => data })
  client.insert(COLUMN_FAMILY, LATEST, { LATEST => id })
end

options = parse_options(ARGV)
client = Cassandra.new(KEYSPACE, "#{options[:host]}:#{options[:port]}")
upload_package(client, build_package(options))
