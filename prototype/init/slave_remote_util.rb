# Author: Yuri Gorshenin

$:.unshift File.join(File.dirname(__FILE__), '..')

require 'drb'
require 'lib/net/allocator_slave'

# Class contains several methods to
# control remote slave.
class SlaveRemoteUtil
  REQUIRED_OPTIONS = [:user, :host, :identity, :dst, :port, :db_host, :db_port, :id, :logfile, :server_host, :server_port, :resources]
  STRONG_OPTIONS = REQUIRED_OPTIONS # Options that needed to start remote services
  WEAK_OPTIONS = [:host, :port] # Options that needed to down or check status of remote services
  
  DEFAULT_OPTIONS = {
    :user => ENV['USER'],
    :identity => File.expand_path('~/.ssh/compute'),
    :dst => '.',
    :port => AllocatorSlave::DEFAULT_OPTIONS[:port],
    :db_port => 9160,
    :server_port => AllocatorSlave::DEFAULT_OPTIONS[:server_port],
    :logfile => AllocatorSlave::DEFAULT_OPTIONS[:logfile],
  }
  
  REQUIRED_FILES = ['slave_core.rb', 'slave_init.rb'].map{|file| File.join(File.dirname(__FILE__), file)}
  SLAVE_OPTIONS = [:id, :logfile, :port, :server_host, :server_port, :resources]
  SLAVEUTIL_PATH = File.join('allocator', 'slaveutil.rb')

  def initialize(options)
    @options = DEFAULT_OPTIONS.merge(options)
    @login = @options[:user] + '@' + @options[:host]
    @ssh_options = "-n -T -o 'UserKnownHostsFile /dev/null' -o 'CheckHostIP no' -o 'StrictHostKeyChecking no' -i #{@options[:identity]} -A -p 22"
    @scp_options = "-o 'UserKnownHostsFile /dev/null' -o 'CheckHostIP no' -o 'StrictHostKeyChecking no' -i #{@options[:identity]}"
    DRb.start_service
  end

  # Ups single node on remote server.
  # Options may contain key :raise_if_fails, what means, that
  # if some command fails, exception is raised.
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

  # Raises exception, if fails
  def down
    begin
      slave = DRbObject.new_with_uri("druby://#{@options[:host]}:#{@options[:port]}")
      slave.down
    rescue DRb::DRbConnError => e
    end
  end

  # Raises exception, if fails.
  def status
    begin
      slave = DRbObject.new_with_uri("druby://#{@options[:host]}:#{@options[:port]}")
      return slave.status
    rescue DRb::DRbConnError => e
      return 'seems that server is down'
    end
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
