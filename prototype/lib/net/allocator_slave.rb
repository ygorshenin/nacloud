# Author: Yuri Gorshenin

require 'drb'
require 'lib/net/allocator_utils'
require 'logger'

# Class represents single worker.
# Can only run binaries from work directory.
class AllocatorSlave
  include AllocatorUtils
  include DRbUndumped

  OPTIONS = [ :port, :root_dir, :home_dir, :logfile ]
  
  def initialize(options = {})
    @options = {
      :root_dir => 'slave',
      :home_dir => 'home',
    }.merge(options)

    @options[:root_dir] = File.expand_path(@options[:root_dir])

    @logger = Logger.new(@options[:logfile] || STDERR)
    
    create_directory(@options[:root_dir])
    Dir.chdir(@options[:root_dir])
    create_directory(@options[:home_dir])
  end

  # Tries to run binary for specified user in different thread.
  def run_binary(user_id, options)
    Thread.new do
      if not options.has_key?(:binary)
        @logger.error("for user '#{user_id}' binary is not specified")
      else
        binary = options[:binary]
        binary += ' ' + options[:args] if options[:args]
        cmd = "cd #{File.join(@options[:home_dir], user_id)};" + binary
        
        reruns = options[:reruns] || 1
        if run_cmd_times(cmd, reruns)
          @logger.info("success in running '#{cmd}'")
        else
          @logger.info("failed to run '#{cmd}' #{reruns} times")
        end
      end
    end
  end
end
