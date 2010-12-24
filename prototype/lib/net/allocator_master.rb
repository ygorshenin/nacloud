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
    
    @status = :created
  end

  # Starts DRb service.
  def up(uri)
    @logger.info "running service #{uri}"
    DRb.start_service uri, self
    @db_client.start "druby://#{@options[:host]}:#{@options[:db_client_port]}"
    trap('INT') { down }
    @status = :running
    DRb.thread.join
  end

  # Stops DRb service.
  def down
    DRb.stop_service
    @db_client.stop
    @status = :stopped
    @logger.info "master stopped"
    @logger.close
  end

  # Returns master status
  def status
    return @status
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
  # Returns pair [ success, message ]
  def up_job(job)
    return [false, 'incorrect job description'] unless job
    @mutex.synchronize do
      if job[:replicas] > 1 and job[:options][:different_nodes] == true
        return distributively_run_job(job)
      else
        return greedy_run_job(job)
      end
    end
  end

  # Stops and deletes job, removes all data from db and slaves.
  # Returns pair [ success, message ]
  def down_job(job)
    return [false, 'incorrect job description'] unless job
    ok, io = true, StringIO.new
    begin
      if not @db_client.exists_job? job
        @logger.warn "can't delete job '#{job[:user]}:#{job[:name]}': no such job"
        return [false, 'no such job']
      end

      # Retrieves full job description from database,
      # because job argument may contain incorrect info about :replicas
      job = @db_client.get_job_description(job)
      @db_client.delete_job job
      job[:replicas].times do |replica|
        task = {:replica => replica}.merge(job)
        key = AllocatorUtils::get_task_key task
        result = down_task_on_slave(@job_to_slave[key], task)
        if not result.first
          ok = false
          io.puts result.second
        end
      end
      return [ok, (ok ? 'success' : io.string)]
    rescue Exception => e
      @logger.error e
      return [false, e.message]
    end
  end

  def get_db_client_port
    @options[:db_client_port]
  end

  private

  # Tries to run job greedy.
  # Returns pair [success, message]
  def distributively_run_job(job)
    return [false, 'incorrect job description'] unless job
    return [false , 'no available resources'] if @slaves.map { |id, slave| (available?(slave, job) ? 1 : 0) }.sum < job[:replicas]
    replica = 0
    @slaves.each do |id, slave|
      if available?(slave, job)
        up_task_on_slave(slave, {:replica => replica}.merge(job))
        replica += 1
        return [true, 'success'] if replica == job[:replicas]
      end
    end
    return [false, 'strange point']
  end

  # Tries to run job greedy.
  # Returns pair [success, message]
  def greedy_run_job(job)
    return [false, 'incorrect job description'] unless job
    return [false, 'no available resources'] if @slaves.map { |id, slave| num_available?(slave, job) }.sum < job[:replicas]
    replica = 0
    @slaves.each do |id, slave|
      num_available?(slave, job).times do
        up_task_on_slave(slave, {:replica => replica}.merge(job))
        replica += 1
        return [true, 'success'] if replica == job[:replicas]
      end
    end
    return [false, 'strange point']
  end
  
  # Checks, if slave is available.
  # This checks contain resource checking.
  # Returns failse, if fails.
  # Checks arguments.
  def available?(slave, task)
    return false unless slave and task
    begin
      slave = DRbObject::new_with_uri(AllocatorUtils::get_uri(slave))
      return slave.available? task
    rescue Exception => e
      @logger.error e
      return false
    end
  end

  # Checks how many instances of that task
  # can be runned on that slave.
  # If connection fails, returns zero.
  # Checks arguments.
  def num_available?(slave, task)
    return false unless slave and task
    begin
      slave = DRbObject::new_with_uri(AllocatorUtils::get_uri(slave))
      return slave.num_available?(task)
    rescue Exception => e
      @logger.error e
      return 0
    end
  end

  # Runs task on slave.
  # Slave and task are hashes of options.
  # Returns pair [ success, message ].
  # Checks arguments.
  def up_task_on_slave(slave, task)
    return [false, 'no such slave'] unless slave
    return [false, 'no such task'] unless task
    uri, key = AllocatorUtils::get_uri(slave), AllocatorUtils::get_task_key(task)
    begin
      client = DRbObject::new_with_uri(uri)
      client.add_task task
      client.start_task task
      @job_to_slave[key] = slave
      @logger.info("task #{key} started on slave #{uri}")
      return [true, 'success']
    rescue Exception => e
      @logger.error e.message
      return [false, e.message]
    end
  end

  # Kills task with options on slave.
  # Slave and task are hashes of options.
  # Returns pair [ success, message ].
  # Checks arguments.
  def down_task_on_slave(slave, task)
    return [false, 'no such slave'] unless slave
    return [false, 'no such task'] unless task
    uri, key = AllocatorUtils::get_uri(slave), AllocatorUtils::get_task_key(task)
    begin
      client = DRbObject::new_with_uri(uri)
      client.delete_task(task)
      @job_to_slave.delete(key)
      @logger.info("task #{key} killed on slave #{uri}")
      return [true, 'success']
    rescue Exception => e
      @logger.error e.message
      return [false, e.message]
    end
  end
end
