#!/usr/bin/ruby
# Author: Yuri Gorshenin

require 'open3'
require 'optparse'

DEFAULT_OPTIONS = {
  :user => ENV['USER'],
  :identity => '~/.ssh/compute',
  :dst => 'slave',
}

REQUIRED_OPTIONS = [:host, :user, :identity, :db_host, :db_port, :id, :logfile, :port, :server_host, :server_port, :resources]
SLAVE_OPTIONS = [:id, :logfile, :port, :server_host, :server_port, :resources]

def parse_options(argv)
  options, parser = DEFAULT_OPTIONS, OptionParser.new

  parser.on('--host=HOST', "host, on which slave will be installed", String) { |host| options[:host] = host }
  parser.on('--user=USER', "user, which login will be used", "default=#{DEFAULT_OPTIONS[:user]}", String) { |user| options[:user] = user }
  parser.on('--identity=FILE', "ssh identity file", "default=#{DEFAULT_OPTIONS[:identity]}", String) { |identity| options[:identity] = identity }
  parser.on('--dst=DIR', "where to put slave file", "default=#{DEFAULT_OPTIONS[:dst]}", String) { |dst| options[:dst] = dst }
  # Slave specified options
  parser.on("--db_host=HOST", "Cassandra's host", String) { |db_host| options[:db_host] = db_host }
  parser.on("--db_port=PORT", "Cassandra's port", String) { |db_port| options[:db_port] = db_port }
  parser.on("--id=ID", "id of slave, must be unique", String) { |id| options[:id] = id }
  parser.on("--logfile=FILE", "name of logfile", String) { |logfile| options[:logfile] = logfile }
  parser.on("--port=PORT", "port, on which slave will be available", "by master", Integer) { |port| options[:port] = port }
  parser.on("--server_host=HOST", "where is server?", String) { |server_host| options[:server_host] = server_host }
  parser.on("--server_port=PORT", "on which port?", String) { |server_port| options[:server_port] = server_port }
  parser.on("--resources=FILE", "local file with resources description", String) { |resources| options[:resources] = resources }

  parser.parse(*argv)

  REQUIRED_OPTIONS.each do |option|
    raise ArgumentError.new("#{option} must be specified") unless options[option]
  end
  options[:identity] = File.expand_path(options[:identity])
  options[:resources] = File.expand_path(options[:resources])
  options
end

begin
  options = parse_options(ARGV)
rescue Exception => e
  STDERR.puts e
  exit -1
end

SSH_OPTIONS = "-n -T -o 'UserKnownHostsFile /dev/null' -o 'CheckHostIP no' -o 'StrictHostKeyChecking no' -i #{options[:identity]} -A -p 22"
SCP_OPTIONS = "-o 'UserKnownHostsFile /dev/null' -o 'CheckHostIP no' -o 'StrictHostKeyChecking no' -i #{options[:identity]}"
LOGIN = options[:user] + '@' + options[:host]

REQUIRED_FILES = ['slave_core.rb', 'slave_init.rb', options[:resources]]

options[:resources] = File.basename(options[:resources])
SLAVE_UTIL_PATH = File.join('allocator', 'slaveutil.rb')
OPTIONS = SLAVE_OPTIONS.map { |option| "--#{option}=#{options[option]}" }.join(' ')

REMOTE_COMMANDS = [
                   "./slave_init.rb --host=#{options[:db_host]} --port=#{options[:db_port]} --dst=#{options[:dst]}",
                   "#{File.join(options[:dst], SLAVE_UTIL_PATH)} #{OPTIONS}",
                   ]

# Uploads list of files into server.
# Options must contain :scp_options and :login keys.
# Raises exception, if fails.
def upload_files(files, options)
  run_cmd("scp #{options[:scp_options]} #{Array(files).join(' ')} #{options[:login]}:.")
end

# Execute list of commands remotely
# Options must contain :ssh_options and :login keys.
# Raises exception, if fails.
# Returns remote programs output.
def remote_execute(cmd, options)
  cmd = "ssh #{options[:ssh_options]} #{options[:login]} #{cmd}"
  run_cmd(cmd, options)
end

# Runs cmd.
# Options may has a key :raise_if_fails.
# Returns output of command
def run_cmd(cmd, options = {})
  STDERR.puts cmd
  result = `#{cmd}`
  raise RuntimeError.new(result) unless $?.success?
  return result
end

begin
  STDERR.puts "uploading files: #{REQUIRED_FILES.join(', ')}... "
  upload_files(REQUIRED_FILES, :scp_options => SCP_OPTIONS, :login => LOGIN, :raise_if_fails => true)
  options[:resources] = File.basename(options[:resources])
  REMOTE_COMMANDS.each { |cmd| remote_execute(cmd, :ssh_options => SSH_OPTIONS, :login => LOGIN, :raise_if_fails => true) }
rescue Exception => e
  STDERR.puts e
  STDERR.puts e.backtrace
  exit -1
end
