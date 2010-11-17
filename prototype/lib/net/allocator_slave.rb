# Author: Yuri Gorshenin

require 'drb'
require 'lib/net/allocator_utils'
require 'logger'

# Class represents single worker.
# Can only run binaries from work directory.
class AllocatorSlave
  include AllocatorUtils
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
end
