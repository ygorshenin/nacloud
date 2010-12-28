#!/usr/bin/ruby
# Author: Yuri Gorshenin

require 'optparse'

class SlaveRemoteUtil
  REQUIRED_OPTIONS = [:host, :user, :identity, :db_host, :db_port, :id, :logfile, :port, :server_host, :server_port, :resources]
  
  DEFAULT_OPTIONS = {
    :user => ENV['USER'],
    :identity => File.expand_path('~/.ssh/compute'),
    :dst => 'slave',
  }
  
  REQUIRED_FILES = ['slave_core.rb', 'slave_init.rb'].map { |file| File.join(File.dirname(__FILE__), file) }
  SLAVE_OPTIONS = [:id, :logfile, :port, :server_host, :server_port, :resources]
  SLAVEUTIL_PATH = File.join('allocator', 'slaveutil.rb')

  def initialize(options)
    @options = options
    @login = @options[:user] + '@' + @options[:host]
    @ssh_options = "-n -T -o 'UserKnownHostsFile /dev/null' -o 'CheckHostIP no' -o 'StrictHostKeyChecking no' -i #{@options[:identity]} -A -p 22"
    @scp_options = "-o 'UserKnownHostsFile /dev/null' -o 'CheckHostIP no' -o 'StrictHostKeyChecking no' -i #{@options[:identity]}"
  end

  # Ups single node on remote server.
  def up(options = {})
    files = REQUIRED_FILES.push(@options[:resources])
    upload_files(files, options)

    args = @options.dup
    args[:resources] = File.basename(args[:resources])

    args = SLAVE_OPTIONS.map{|option| "--#{option}=#{args[option]}"}.join(' ')
    commands = [
                "./slave_init.rb --host=#{@options[:db_host]} --port=#{@options[:db_port]} --dst=#{@options[:dst]}",
                "#{File.join(@options[:dst], SLAVEUTIL_PATH)} #{args}",
               ]
    commands.each{|command| remote_execute(command, options)}
  end

  private
  
  # Uploads list of files into server.
  # Options must contain :scp_options and :login keys.
  # Raises exception, if fails.
  def upload_files(files, options)
    run_cmd("scp #@scp_options #{Array(files).join(' ')} #@login:.")
  end
  
  # Executes one command remotely.
  # Raises exception, if fails.
  # Returns remote programs output.
  def remote_execute(cmd, options = {})
    cmd = "ssh #@ssh_options #@login #{cmd}"
    run_cmd(cmd, options)
  end

  # Runs cmd.
  # Options may has a key :raise_if_fails.
  # Returns output of command.
  def run_cmd(cmd, options = {})
    result = `#{cmd}`
    raise RuntimeError.new(result) unless $?.success?
    return result
  end
end

def parse_options(argv)
  options, parser = SlaveRemoteUtil::DEFAULT_OPTIONS, OptionParser.new

  # General options
  parser.on('--host=HOST', "host, on which slave will be installed", String) { |host| options[:host] = host }
  parser.on('--user=USER', "user, which login will be used", "default=#{options[:user]}", String) { |user| options[:user] = user }
  parser.on('--identity=FILE', "ssh identity file", "default=#{options[:identity]}", String) { |identity| options[:identity] = identity }
  parser.on('--dst=DIR', "where to put slave file", "default=#{options[:dst]}", String) { |dst| options[:dst] = dst }
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

  SlaveRemoteUtil::REQUIRED_OPTIONS.each do |option|
    raise ArgumentError.new("#{option} must be specified") unless options[option]
  end
  
  options[:identity] = File.expand_path(options[:identity])
  options[:resources] = File.expand_path(options[:resources])
  return options
end

begin
  options = parse_options(ARGV)
rescue Exception => e
  STDERR.puts e
  STDERR.puts e.backtrace
  exit -1
end

begin
  util = SlaveRemoteUtil.new(options)
  util.up(:raise_if_fails => true)
rescue Exception => e
  STDERR.puts e
  STDERR.puts e.backtrace
  exit -1
end
