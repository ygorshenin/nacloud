# Author: Yuri Gorshenin

require 'drb'
require 'lib/ext/core_ext'
require 'lib/net/allocator_utils'
require 'lib/net/task/resource_manager'
require 'lib/net/task/task_pool'
require 'lib/package/spm'
require 'logger'

# Class represents single worker.
class AllocatorSlave
  include DRbUndumped

  OPTIONS = [:id, :host, :port, :root_dir, :home_dir, :server_host, :server_port, :register_timeout, :resources]

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

    # Creating root directory and home subdirectory,
    # Chdirs into root directory
    FileUtils.mkdir_p(@options[:root_dir])
    Dir.chdir(@options[:root_dir])
    FileUtils.mkdir_p(@options[:home_dir])

    # Creating task pool
    @pool = TaskPool.new(ResourceManager.new(@options[:resources]))
    
    @logger = Logger.new(@options[:logfile] || STDERR)

    @status = :created
  end

  # Start allocator slave DRb service.
  def up(uri)
    @logger.info("running service #{uri}")
    DRb.start_service uri, self
    Thread.new { register_slave }
    trap('INT') { down }
    @status = :running
    DRb.thread.join
  end

  # Periodically connects to server and registers.
  def register_slave
    uri = "druby://#{@options[:server_host]}:#{@options[:server_port]}"
    slave = { :id => @options[:id], :host => @options[:host], :port => @options[:port] }
    ok = false
    loop do
      begin
        server = DRbObject.new_with_uri(uri)
        server.register_slave(slave)
        if not ok
          @logger.info("successfully registered")
          ok = true
        end
      rescue Exception => e
        if ok
          @logger.warn("can't update server")
          ok = false
        end
      end
      sleep @options[:register_timeout]
    end
  end

  # Stop allocator slave DRb service.
  def down
    DRb.stop_service
    @status = :stopped
    @logger.info("slave stopped")
    @logger.close
  end

  def status
    return @status
  end

  # Checks, is it possible to run that task.
  def available?(task)
    @pool.available?(task[:resources])
  end

  # Checks, how many instances of that task may be added.
  def num_available?(task)
    @pool.num_available?(task[:resources])
  end

  # Checks, if this node alive.
  def alive?(options)
    true
  end

  # Tries to add new task.
  # No resource checks, but TaskException if that task already here.
  def add_task(task)
    add_task_infrastructure(task)
    install_task_packages(task)
    task[:home] = File.join(AllocatorUtils::get_task_home(@options[:home_dir], task), @options[:vmdir_job])
    @pool.add(task)
    @logger.info "added task #{AllocatorUtils::get_task_key(task)}"
  end

  # Tries to start task.
  # Raises TaskException if there are no such task.
  def start_task(task)
    @pool.start(task)
    @logger.info "started task #{AllocatorUtils::get_task_key(task)}"
  end

  def restart_task(task)
    @pool.stop(task)
    install_task_packages(task)
    @pool.start(task)
    @logger.info "restarted task #{AllocatorUtils::get_task_key(task)}"
  end

  # Tries to stop task.
  # Raises TaskException if there are no such task.
  def stop_task(task)
    @pool.stop(task)
    @logger.info "stopped task #{AllocatorUtils::get_task_key(task)}"
  end

  # Tries to delete task.
  # Raises TaskException if there are no such task.
  def delete_task(task)
    @pool.delete(task)
    delete_task_infrastructure(task)
    @logger.info("deleted task #{AllocatorUtils::get_task_key(task)}")
  end

  private

  def get_db_client
    uri = "druby://#{@options[:server_host]}:#{@options[:server_port]}"    
    server = DRbObject.new_with_uri(uri)
    port = server.get_db_client_port
    DRbObject.new_with_uri("druby://#{@options[:server_host]}:#{port}")
  end

  # Recreates job vmdir, install packages (without downloading them),
  # downloads binary from db.
  def install_task_packages(task)
    base = AllocatorUtils::get_task_home(@options[:home_dir], task)

    # Recreates job vmdir
    FileUtils.rm_rf(File.join(base, @options[:vmdir_job]))
    FileUtils.mkdir_p(File.join(base, @options[:vmdir_job]))

    # Download binary from database, if needed.
    if task.has_key?(:binary)
      path = File.join(base, @options[:vmdir_job], File.basename(task[:binary]))
      binary = get_db_client.get_binary(task)
      File.open(path, 'w') { |file| file.write(binary) }
      FileUtils.chmod(755, path)
    end

    # Installs packages from packages vmdir.
    task[:packages].each do |package|
      source = File.join(base, @options[:vmdir_packages], package)
      target = File.join(base, @options[:vmdir_job], package)
      FileUtils.mkdir_p(target)
      SPM::install(source, target)
    end
  end
  
  # Creates all needed directories, downloads packages from db.
  def add_task_infrastructure(task)
    base = AllocatorUtils::get_task_home(@options[:home_dir], task)
    FileUtils.mkdir_p(File.join(base, @options[:vmdir_job]))
    FileUtils.mkdir_p(File.join(base, @options[:vmdir_packages]))
    
    task[:packages].each do |package|
      source = File.join(base, @options[:vmdir_packages], package)
      target = File.join(base, @options[:vmdir_job], package)
      FileUtils.mkdir_p(target)
      package = get_db_client.get_package({ :package_name => package }.merge(task))
      File.open(source, 'w') { |file| file.write(package) }
    end
  end

  # Deletes all used directories.
  def delete_task_infrastructure(task)
    FileUtils.rm_rf(AllocatorUtils::get_task_home(@options[:home_dir], task))
  end
end
