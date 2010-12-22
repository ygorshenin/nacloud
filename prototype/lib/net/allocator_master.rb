# Author: Yuri Gorshenin

require 'drb'
require 'lib/ext/core_ext'
require 'lib/net/allocator_slave'
require 'lib/net/allocator_utils'
require 'lib/net/database_system'
require 'logger'
require 'set'
require 'thread'
require 'timeout'

# Class represents allocator master.
# May be used as bot-master. Listens for slaves, controls jobs
class AllocatorMaster
  include DRbUndumped

  OPTIONS = [:host, :port, :db_client_port, :db_host, :db_port, :allocator_timeout]

  # Default server options. May be used in command-line utils as default values.
  DEFAULT_OPTIONS = {
    :host => `hostname`.strip,
    :allocator_timeout => 1.seconds, # How often checks available nodes
  }

  # Slaves is an Array of slaveses Hashes.
  # Options contains work information about root directory, host on which
  # master is runned and so on
  def initialize(options)
    @options = DEFAULT_OPTIONS.merge(options)
    @db_client = DatabaseSystem.new(:host => @options[:db_host], :port => @options[:db_port])
    # @slaves is a Hash { slave[:id] => slave }
    # @job_to_slave is a Hash { :job_id => slave }
    # @jobs is a Hash { :job_id => job }
    @slaves, @job_to_slave, @jobs = {}, {}, {}
    @logger = Logger.new(@options[:logfile] || STDERR)
    # Mutex for slaves mutual execution access
    @mutex = Mutex.new
  end

  # Starts DRb service.
  def start(uri)
    @logger.info "running service #{uri}"
    DRb.start_service uri, self
    @db_client.start "druby://#{@options[:host]}:#{@options[:db_client_port]}"
    DRb.thread.join
  end

  # Stops DRb service.
  def stop
    DRb.stop_service
    @db_client.stop
    @logger.info "master stopped"
  end

  # Register slave (but this slave may be already registered).
  def register_slave(slave)
    @mutex.synchronize do
      if not @slaves.has_key? slave[:id]
        @logger.info "registering slave #{AllocatorUtils::get_uri(slave)}"
      end
      @slaves[slave[:id]] = slave
    end
  end

  # Starts new job.
  # Returns true, if success.
  def up_job(options)
    @mutex.synchronize do
      if options[:replicas] > 1 and options[:options][:different_nodes] == true
        distributively_run_job options
      else
        greedy_run_job options
      end
    end
  end

  # Stops and deletes job, removes all data from db
  # Returns true, if success.
  def down_job(options)
    begin
      if not @db_client.exists_job?(options)
        @logger.warn "can't delete job #{options[:user]}:#{options[:name]}"
        return false
      end

      options[:replicas].times do |replica|
        job_options = { :replica => replica }.merge(options)
        task = AllocatorUtils::get_task_key job_options
        next if not @job_to_slave.has_key? task
        kill_job_on_slave(@job_to_slave[task], job_options)
      end

      @db_client.delete_job options
      return true
    rescue Exception => e
      @logger.error e
      return false
    end
  end

  def get_db_client_port
    @options[:db_client_port]
  end

  private

  def distributively_run_job(options)
    used_slaves = Set.new
    options[:replicas].times do |replica|
      loop do
        # Checks available slave that not in used_slaves
        slave = @slaves.find { |id, slave| not used_slaves.include?(id) and available?(slave, options) }
        # If fails, tries to find available slave
        slave = @slaves.find { |id, slave| available?(slave, options) } unless slave
        if not slave.nil?
          used_slaves.add(slave.first)
          run_job_on_slave(slave.second, { :replica => replica }.merge(options))
          break
        else
          sleep @options[:allocator_timeout]
        end
      end
    end
  end

  def greedy_run_job(options)
    options[:replicas].times do |replica|
      loop do
        slave = @slaves.find { |id, slave| available?(slave, options) }
        if not slave.nil?
          run_job_on_slave(slave.second, { :replica => replica }.merge(options))
          break
        else
          sleep @options[:allocator_timeout]
        end
      end
    end
  end
  
  # Checks, if slave is available.
  # This checks may contain resource checking.
  def available?(slave, options)
    begin
      slave = DRbObject::new_with_uri(AllocatorUtils::get_uri(slave))
      return slave.available?(options)
    rescue Exception => e
      @logger.error e
      return false
    end
  end

  # Runs job with options on slave.
  # :replica key must be specified in options.
  def run_job_on_slave(slave, options)
    uri, task = AllocatorUtils::get_uri(slave), AllocatorUtils::get_task_key(options)
    begin
      object = DRbObject::new_with_uri(uri)
      object.add_task options
      object.start_task options
      @job_to_slave[task] = slave
      @logger.info("task #{task} started on slave #{uri}")
    rescue Exception => e
      @logger.error e
    end
  end

  # Kills job with options on slave.
  # :replica key must be specified in options.
  def kill_job_on_slave(slave, options)
    uri, task = AllocatorUtils::get_uri(slave), AllocatorUtils::get_task_key(options)    
    begin
      object = DRbObject::new_with_uri(uri)
      object.kill_task(options)
      object.del_task(options)
      @job_to_slave.delete(task)
      @logger.info("task #{task} killed on slave #{uri}")
    rescue Exception => e
      @logger.error(e)
    end
  end
end
