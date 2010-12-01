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
    @logger = Logger.new(@options[:logfile] || STDERR)
  end

  # Start DRb service
  def start(uri)
    @logger.info "running service #{uri}"
    DRb.start_service uri, self
    DRb.thread.join
  end

  def stop
    @logger.info "stopping service"
    DRb.stop_service
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
end
