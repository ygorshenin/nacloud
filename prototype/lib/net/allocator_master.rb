# Author: Yuri Gorshenin

require 'drb'

require 'lib/ext/core_ext'
require 'lib/net/allocator_slave'
require 'lib/net/allocator_utils'
require 'logger'
require 'thread'
require 'timeout'

# Class represents allocator master.
# May be used as bot-master. Only starts slaves, gets status info, stops and runs jobs.
class AllocatorMaster
  include AllocatorUtils
  include DRbUndumped

  # Default server options. May be used in command-line utils as default values.
  DEFAULT_OPTIONS = {
    :host => `hostname`.strip,
  }

  # Slaves is an Array of slaveses Hashes.
  # Router is a Hash { user_id => slave_id }
  # Options contains work information about root directory, path to slave_runnder,
  # how many times we may reload slaves and so on.
  def initialize(router, options = {})
    @slaves = {}
    @router = {}
    router.each { |k, v| @router[k.to_s] = Array(v).map { |slave| slave.to_s } }
    @options = DEFAULT_OPTIONS.merge(options)
    @logger = Logger.new(@options[:logfile] || STDERR)

    @mutex = Mutex.new
  end

  # Start DRb service
  def start(uri)
    @logger.info "running service #{uri}"
    DRb.start_service uri, self
    DRb.thread.join
  end

  # Stop DRb service
  def stop
    @logger.info "stopping service"
    DRb.stop_service
  end

  def update_slave(slave)
    @mutex.synchronize { @slaves[slave[:id]] = slave }
  end

  def run_binary_on_slave(slave, user_id, package, options = {})
    @logger.info("trying to run binary from #{user_id} on #{slave[:id]}")
    uri = "druby://#{slave[:host]}:#{slave[:port]}"
    begin
      slave = DRbObject.new_with_uri(uri)
      slave.run_binary(user_id, package, options)
      return true
    rescue Exception => e
      @logger.info e.message
      return false
    end      
  end
  
  # Run binary from user_id on slave, which is assigned to this user
  def run_binary(user_id, package, options = {})
    if not @router[user_id]
      @logger.info "can't route for #{user_id}"
      return false
    end
    @router[user_id].each do |slave_id|
      @mutex.synchronize do
        if @slaves[slave_id] and run_binary_on_slave(@slaves[slave_id], user_id, package, options)
          @logger.info("running binary from #{user_id} on #{slave_id}")
          return true
        end
      end
    end
    return false
  end
end
