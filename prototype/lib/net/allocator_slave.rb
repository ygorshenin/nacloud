# Author: Yuri Gorshenin

require 'drb'
require 'lib/ext/core_ext'
require 'lib/net/allocator_utils'
require 'lib/package/spm'
require 'logger'
require 'pty'
require 'thread'

# Class represents single task.
# options must have: :home, [:binary], [:command], [:reruns]
# :binary must be short, i.e. not "/some/long/path/binary.bin" but "binary.bin".
class AllocatorTask
  def initialize(options)
    @options = options
    
    @cmd = "cd #{@options[:home]};"
    if @options.has_key? :binary
      @cmd += './' + @options[:binary]
    elsif @options.has_key? :command
      @cmd += @options[:command]
    end
  end
  
  def start
    @pid = fork do
      Process::setsid
      STDIN.reopen('/dev/null', 'r')
      STDOUT.reopen('/dev/null', 'w')
      STDERR.reopen('/dev/null', 'w')
      exec @cmd
    end
    Process::detach(@pid)
  end

  def kill
    Process::kill('-TERM', @pid)
  end
end

# Class represents single worker.
class AllocatorSlave
  include DRbUndumped

  OPTIONS = [:id, :host, :port, :root_dir, :home_dir, :server_host, :server_port, :register_timeout]

  DEFAULT_OPTIONS = {
    :vmdir_job => 'job',
    :vmdir_packages => 'packages',
    
    :host => `hostname`.strip,
    :root_dir => '.',
    :home_dir => 'home',
    :register_timeout => 2.seconds,
  }

  REQUIRED_OPTIONS = OPTIONS.select { |k| not DEFAULT_OPTIONS.has_key?(k) }
  
  def initialize(options = {})
    @options = DEFAULT_OPTIONS.merge(options)
    @options[:root_dir] = File.expand_path(@options[:root_dir])

    # Creating root directory and home subdirectory
    # Chdirs into root directory
    FileUtils.mkdir_p(@options[:root_dir])
    Dir.chdir(@options[:root_dir])
    FileUtils.mkdir_p(@options[:home_dir])
    
    @logger = Logger.new(@options[:logfile] || STDERR)

    # Tasks hash, maps "user:job" to AllocatorTask object
    @tasks = {}
  end

  # Start allocator slave DRb service
  def start(uri)
    @logger.info("running service #{uri}")
    DRb.start_service uri, self
    Thread.new { register_slave }
    DRb.thread.join
  end

  def register_slave
    uri = "druby://#{@options[:server_host]}:#{@options[:server_port]}"
    slave = { :id => @options[:id], :host => @options[:host], :port => @options[:port] }
    last_state = :fail
    loop do
      begin
        server = DRbObject.new_with_uri(uri)
        server.register_slave(slave)
        if last_state == :fail
          @logger.info("successfully registered")
          last_state = :success
        end
      rescue Exception => e
        if last_state == :success
          @logger.warn("can't update server")
          last_state = :fail
        end
      end
      sleep @options[:register_timeout]
    end
  end

  # Stop allocator slave DRb service
  def stop
    DRb.stop_service
    @logger.info("slave stopped")
  end

  # Checks, if this node can run this task
  def available?(options)
    true # TODO: There must be resource control
  end

  # Checks, if this node alive
  def alive?(options)
    true
  end

  # Options must have:
  # :user, :job, [:binary], [:command], :replicas, :options { :reruns }
  def add_task(options)
    add_task_infrastructure(options)
    options[:home] = File.join(get_task_home(options), @options[:vmdir_job])
    task = AllocatorUtils::get_task_key(options)
    @tasks[task] = AllocatorTask.new(options)

    @logger.info "added task #{task}"
  end

  def start_task(options)
    task = AllocatorUtils::get_task_key(options)
    @tasks[task].start if @tasks.has_key? task

    @logger.info "started task #{task}"
  end

  def kill_task(options)
    task = AllocatorUtils::get_task_key(options)
    if @tasks.has_key? task
      @tasks[task].kill
      @logger.info("killed task #{task}")
    else
      @logger.warn("no such task #{task}")
    end
  end

  def del_task(options)
    task = AllocatorUtils::get_task_key(options)
    return unless @tasks.has_key? task
    del_task_infrastructure(options)
    @tasks.delete(task)

    @logger.info("deleted task #{task}")
  end

  private

  def get_db_client
    uri = "druby://#{@options[:server_host]}:#{@options[:server_port]}"    
    server = DRbObject.new_with_uri(uri)
    port = server.get_db_client_port
    DRbObject.new_with_uri("druby://#{@options[:server_host]}:#{port}")
  end
  
  # Creates all needed directories
  def add_task_infrastructure(options)
    base = get_task_home(options)
    FileUtils.mkdir_p(File.join(base, @options[:vmdir_job]))
    FileUtils.mkdir_p(File.join(base, @options[:vmdir_packages]))
    
    if options.has_key?(:binary)
      path = File.join(base, @options[:vmdir_job], File.basename(options[:binary]))
      binary = get_db_client.get_binary(options)
      File.open(path, 'w') { |file| file.write(binary) }
      FileUtils.chmod(755, path)
    end

    if options.has_key?(:packages)
      options[:packages].each do |package_name|
        source = File.join(base, @options[:vmdir_packages], package_name)
        target = File.join(base, @options[:vmdir_job], package_name)
        FileUtils.mkdir_p(target)
        package = get_db_client.get_package({ :package_name => package_name }.merge(options))
        File.open(source, 'w') { |file| file.write(package) }
        SPM::install(source, target)
      end
    end
  end

  # Deletes all used directories
  def del_task_infrastructure(options)
    FileUtils.rm_rf(get_task_home(options))
  end

  def get_task_home(options)
    File.join(@options[:home_dir], options[:user], options[:job] + '.' + options[:replica].to_s)
  end
end
