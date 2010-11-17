# Author: Yuri Gorshenin

require 'drb'
require 'logger'

# Class represents single worker.
# Can only run binaries from work directory.
class AllocatorSlave
  include DRbUndumped
  
  def initialize(options = {})
    @options = {
      :work_dir => 'work',
    }.merge(options)

    @logger = Logger.new(@options[:logfile] || STDERR)
    create_directory(@options[:work_dir])
  end

  # Tries to run binary for specified user in different thread.
  def run_binary(user, options)
    Thread.new do
      if not options.has_key?(:binary)
        @logger.error "for user '#{user}' binary is not specified"
      else
        binary = options[:binary]
        binary += ' ' + options[:args] if options[:args]
        cmd = File.join(@options[:work_dir], user, binary)

        reruns = options[:reruns] || 1
        if run_cmd_times(cmd, reruns)
          @logger.info "success in running '#{cmd}'"
        else
          @logger.info "failed to run '#{cmd}' #{reruns} times"
        end
      end
    end
  end

  private

  # Creating subdirectory in current directory, if not exists yet.
  # Raises Exception if fails.
  def create_directory(name)
    begin
      Dir.mkdir(name)
    rescue Errno::EEXIST
      raise if not File.directory?(name)
    end
  end

  # Execute cmd in current thread.
  # Returns Process::Status or throws SystemCallError.
  def run_cmd(cmd)
    @logger.info("running command: #{cmd}")
    result = `#{cmd}`
    exit_code = $?
    @logger.info("result of '#{cmd}': #{result.strip}, exit code: #{exit_code}")
    [exit_code, result]
  end

  # Tries to run cmd at most reruns times.
  # Returns true if success.
  def run_cmd_times(cmd, reruns)
    reruns.times do
      begin
        result = run_cmd(cmd)
        return true if result.first.success?
      rescue Exception => e
        @logger.error "can't execute '#{cmd}', cause: #{e.message}"
      end
    end
    false
  end
end
