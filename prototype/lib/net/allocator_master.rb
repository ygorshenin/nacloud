# Author: Yuri Gorshenin

require 'drb'
require 'lib/net/allocator_slave'
require 'lib/net/allocator_utils'
require 'logger'

class AllocatorMaster
  include AllocatorUtils
  include DRbUndumped

  # Slaves is an Array of slaveses Hashes.
  # Router is a Map :user_id => :slave_id.
  # Options contains work information about root directory, path to slave_runnder, how many times we may reload slaves and so on.
  def initialize(slaves, router, options = {})
    @slaves = {}
    slaves.each { |slave| @slaves[slave[:id]] = slave }
    @router = router
    @options = {
      :root_dir => File.join('.'),
      :slave_runner => File.join('allocator', 'slave_runner.rb'),
      :slave_reruns => 10,
    }.merge(options)
    @logger = Logger.new(@options[:logfile] || STDERR)
  end

  # Uploads all system library files to slave's root directory.
  # slave is a Hash with all necessary info (:host, :port, :user, :root_dir).
  def upload_system_files(slave)
    source = File.join(File.expand_path(@options[:root_dir]), '*')
    target = slave[:root_dir]
    
    upload_files(source, target, slave)
  end

  # Runs slave remotely.
  def remote_run_slave(slave)
    reruns = slave[:reruns] || @options[:slave_reruns]
    
    head = "ssh #{slave[:user]}@#{slave[:host]}"
    tail = "ruby -I #{slave[:root_dir]} #{File.join(slave[:root_dir], @options[:slave_runner])}"
    args = []
    
    slave.each do |k, v|
      args.push("--#{k}=#{v}") if AllocatorSlave::OPTIONS.index(k)
    end
    
    run_cmd_times([head, tail, args].join(' '), reruns)
  end

  def run_binary(user_id, options)
    if not options.has_key?(:binary)
      @logger.error("for user '#{user}' binary is not specified")
      return false
    end
    source = Array(options[:data] || []).push(options[:binary])
    slave = @slaves[@router[user]]
    target = File.join(slave[:root_dir],  slave[:home_dir], user_id)
    upload_files(source, target, slave)
    return true
  end
end

slave = {
  :id => 'ygorshenin',
  :host => '172.28.51.174',
  :user => 'ygorshenin',
  :root_dir => 'nslave',
  :home_dir => 'nhome',
  :port => 8080,
  :reruns => 2,
}

slaves = [ slave ]
router = { :alpha => 'ygorshenin' }

master = AllocatorMaster.new(slaves, router)

master.upload_system_files(slave)
master.remote_run_slave(slave)