# Author: Yuri Gorshenin

require 'drb'

# Class contains several methods to
# control remote slave.
class SlaveRemoteUtil
  REQUIRED_OPTIONS = [:host, :user, :identity, :port, :dst, :db_host, :db_port, :id, :logfile, :server_host, :server_port, :resources]
  STRONG_OPTIONS = REQUIRED_OPTIONS
  WEAK_OPTIONS = [:host, :port]
  
  DEFAULT_OPTIONS = {
    :user => ENV['USER'],
    :identity => File.expand_path('~/.ssh/compute'),
    :dst => '.',
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

  # Raises exception, if fails.
  def down
    slave = DRbObject.new_with_uri("druby://#{@options[:host]}:#{@options[:port]}")
    slave.down
  end

  # Raises exception, if fails.
  def status
    slave = DRbObject.new_with_uri("druby://#{@options[:host]}:#{@options[:port]}")
    slave.status
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
