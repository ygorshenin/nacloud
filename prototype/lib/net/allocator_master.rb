# Author: Yuri Gorshenin

require 'drb'
require 'lib/net/allocator_slave'
require 'lib/net/allocator_utils'
require 'logger'

class AllocatorMaster
  include AllocatorUtils
  include DRbUndumped

  DEFAULT_OPTIONS = {
    :host => `hostname`.strip,
    :root_dir => '.',
    :slave_runner => File.join('allocator', 'slave_runner.rb'),
    :slave_reruns => 10,
  }

  # Slaves is an Array of slaveses Hashes.
  # Router is a Map :user_id => :slave_id.
  # Options contains work information about root directory, path to slave_runnder,
  # how many times we may reload slaves and so on.
  def initialize(slaves, router, options = {})
    @slaves = {}
    slaves.each { |slave| @slaves[slave[:id]] = slave }
    @router = router
    @options = DEFAULT_OPTIONS.merge(options)
    @options[:root_dir] = File.expand_path(@options[:root_dir])
    @logger = Logger.new(@options[:logfile] || STDERR)
  end

  # Run all slaves
  def run_slaves
    @slaves.each_value do |slave|
      Thread.new do
        raise RuntimeError.new("can't upload system files") unless upload_system_files(slave)
        remote_run_slave(slave)
      end
    end
  end

  def run_binary(user_id, package, options)
    slave = @slaves[@router[user_id]]
    if not @router[user_id] or not @slaves[@router[user_id]]
      @logger.info "can't route for #{user_id}"
      return false
    end
    uri = "druby://#{slave[:host]}:#{slave[:port]}"
    @logger.info("slave: #{slave.inspect}")
    @logger.info("uri: #{uri}")

    begin
      slave = DRbObject.new nil, uri
      slave.run_binary(user_id, package, options)
      return true
    rescue Exception => e
      @logger.info e
      return false
    end
  end

  private

  # Uploads all system library files to slave's root directory.
  # slave is a Hash with all necessary info (:host, :port, :user, :root_dir).
  def upload_system_files(slave)
    source = File.join(@options[:root_dir], "*")
    target = slave[:root_dir]
    @logger.info "#{source} => #{target}"
    upload_files(source, target, slave)
  end

  # Runs slave remotely.
  def remote_run_slave(slave)
    reruns = (slave[:reruns] || @options[:slave_reruns]).to_i
    
    head = "ssh #{slave[:user]}@#{slave[:host]}"
    tail = "ruby -I #{slave[:root_dir]} #{File.join(slave[:root_dir], @options[:slave_runner])}"
    args = []
    
    slave.each do |k, v|
      args.push("--#{k}=#{v}") if AllocatorSlave::OPTIONS.index(k)
    end
    
    run_cmd_times([head, tail, args].join(' '), reruns)

    @logger.info "slave #{slave[:id]} down"
  end
end
