#!/usr/bin/ruby

# Author: Yuri Gorshenin

# This script connects to Cassandra's database server and
# uploads new version of slave.
# User only must specify database host, port and source directory, from
# which new files will be fetched.
#
# Script is designed to be runned without other parts of system.

require 'cassandra'
require 'digest'
require 'optparse'

include SimpleUUID

KEYSPACE = 'Storage'
COLUMN_FAMILY = :NodeLib

# Parses and check_options options.
# argv is an array with options.
# Throws exception, if fails.
def parse_options(argv)
  options, parser = { :dst => '.' }, OptionParser.new

  parser.on('-h', '--host', "Cassandra's host", String) { |host| options[:host] = host }
  parser.on('-p', '--port', "Cassandra's port", Integer) { |port| options[:port] = port }
  parser.on('-s', '--source', "where to get all packages", "default=.", String) { |src| options[:src] = src }

  parser.parse(*argv)
  check_options(options)

  options
end

# Tries to check options.
# Throws exception, if fails.
def check_options(options)
  options[:src] = File.expand_path(options[:src])
  [:host, :port].each { |option| raise ArgumentError.new("option '#{option}' must be specified") unless options.has_key? option }
  
end

def get_tmp_name
  "tmp.#{Time.now.to_i}.#{Process::pid}"
end

# Build package by option[:sr
def build_package(options)
  
end
