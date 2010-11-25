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

    create_directory(@options[:root_dir])
    Dir.chdir(@options[:root_dir])
    
    @logger = Logger.new(@options[:logfile] || STDERR)
    create_directory(@options[:home_dir])
  end

  # Start allocator slave DRb service
  def start(uri)
    @logger.info("running service #{uri}")
    DRb.start_service uri, self
    DRb.thread.join
  end

  # Stop allocator slave DRb service
  def stop
    @logger.info("stopping service")
    DRb.stop_service
  end

  def install_package(source, user_id, options = {})
    destination = File.join(@options[:home_dir], user_id)
    result = `ruby lib/package/spmutil.rb -i --package_file=#{source} --destination=#{destination}`
    result = $?.success?
    `rm #{source}` if options[:remove_after]
    return result
  end

  # Tries to run binary for specified user in different thread.
  def run_binary(user_id, package, options = {})
    @logger.info "running binary from #{user_id}"
    Thread.new do
      work_dir = File.join(@options[:home_dir], user_id)
      package_file = get_tmp_name
      begin
        @logger.info "creating work directory for #{user_id}"
        create_directory(work_dir)
        @logger.info "creating package file"
        File.open(package_file, 'w') { |file| file.write(package) }
        install_package(package_file, user_id, :remove_after => true)
        
        if not options.has_key?(:binary)
          @logger.warning("for user '#{options[:user_id]}' binary is not specified")
        else
          binary, reruns = File.basename(options[:binary]), options[:reruns] || 1
          cmd = "cd #{work_dir}; ./#{binary}"
          run_cmd_times(cmd, reruns)
        end
      rescue Exception => e
        @logger.info "fails: #{e}"
      end
    end
  end

  private

  def get_tmp_name
    "tmp_#{Time.now.to_i}_#{Process.pid}"    
  end
end
