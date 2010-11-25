# Author: Yuri Gorshenin

require 'drb'

require 'lib/ext/core_ext'
require 'lib/net/allocator_slave'
require 'lib/net/allocator_utils'
require 'logger'
require 'timeout'

# Class represents allocator master.
# May be used as bot-master. Only starts slaves, gets status info, stops and runs jobs.
class AllocatorMaster
  include AllocatorUtils
  include DRbUndumped

  # Default server options. May be used in command-line utils as default values.
  DEFAULT_OPTIONS = {
    :host => `hostname`.strip,
    :root_dir => '.',
    :slave_runner => File.join('allocator', 'slave_runner.rb'),
    :slave_reruns => 1,
    :slave_stop_timeout => 3.seconds,
  }

  # Slaves is an Array of slaveses Hashes.
  # Router is a Hash { user_id => slave_id }
  # Options contains work information about root directory, path to slave_runnder,
  # how many times we may reload slaves and so on.
  def initialize(slaves, router, options = {})
    @slaves = {}
    slaves.each { |slave| @slaves[slave[:id]] = slave }

    @router = router
    @options = DEFAULT_OPTIONS.merge(options)
    # root dir is a place, where all necessary library files are placed.
    @options[:root_dir] = File.expand_path(@options[:root_dir])
    @logger = Logger.new(@options[:logfile] || STDERR)
  end

  # Start DRb service
  def start(uri)
    @slaves_ssh_thread = Thread.new { run_slaves }
    DRb.start_service uri, self
    DRb.thread.join
  end

  # Upload all system files to slaves
  def deploy
    each_slave do |slave|
      msg = upload_system_files(slave) ? "files were successfully uploaded to #{slave[:id]}" : "failed upload files to #{slave[:id]}"
      Thread.current[:status] = msg
    end
  end

  # Stops all slaves and stops drb service
  def stop
    each_slave do |slave|
      msg = remote_stop_slave(slave) ? "#{slave[:id]} was succesfully stopped" : "failed to stop #{slave[:id]}"
      Thread.current[:status] = msg
    end
    if defined? @slaves_ssh_thread
      begin
        Timeout::timeout(@options[:slave_stop_timeout]) { @slaves_ssh_thread.join }
        @logger.info("ssh connections were succesfully stopped")
      rescue Exception => e
        @logger.error(e)
        @logger.info("can't stop ssh connections gracefully")
      end
    end
    DRb.stop_service
  end

  # Run all slaves
  def run_slaves
    @slaves.each_value do |slave|
      Thread.new do
        remote_run_slave(slave)
      end
    end
  end

  # Run binary from user_id on slave, which is assigned to this user
  def run_binary(user_id, package, options)
    if not @router[user_id] or not @slaves[@router[user_id]]
      @logger.info "can't route for #{user_id}"
      return false
    end
    slave = @slaves[@router[user_id]]
    @logger.info("running binary from #{user_id} to #{slave[:id]}")
    uri = "druby://#{slave[:host]}:#{slave[:port]}"
    begin
      slave = DRbObject.new_with_uri(uri)
      slave.run_binary(user_id, package, options)
      return true
    rescue Exception => e
      @logger.info e
      return false
    end
  end

  private

  # Process all slaves in parallel
  def each_slave(&block)
    threads = []
    @slaves.each_value { |slave| threads.push(Thread.new { block[slave] }) }
    threads.each { |t| @logger.info t.join[:status] }
  end

  # Uploads all system library files to slave's root directory.
  # slave is a Hash with all necessary info (:host, :port, :user, :root_dir, :id).
  def upload_system_files(slave)
    source = File.join(@options[:root_dir], "*")
    target = slave[:root_dir]
    upload_files(source, target, slave)
  end

  # Stops remove slave.
  # Returns false, if fails.
  def remote_stop_slave(slave)
    begin
      object = DRbObject.new_with_uri("druby://#{slave[:host]}:#{slave[:port]}")
      object.stop
      return true
    rescue DRb::DRbConnError
      @logger.warn("can't connect to #{slave[:id]}, may be already stopped")
      return true
    rescue Exception => e
      @logger.error(e)
      return false
    end
  end
  
  # Runs slave remotely.
  def remote_run_slave(slave)
    reruns = (slave[:reruns] || @options[:slave_reruns]).to_i

    # Runs slave silently
    args = []
    slave.each do |k, v|
      args.push("--#{k}=#{v}") if AllocatorSlave::OPTIONS.index(k)
    end
    
    head = "ssh #{slave[:user]}@#{slave[:host]}"
    tail = "\"ruby -I #{slave[:root_dir]} #{File.join(slave[:root_dir], @options[:slave_runner])} #{args.join(' ')} \""

    run_cmd_times(head + ' ' + tail, reruns)
  end
end
