# Author: Yuri Gorshenin

# Module contains several common useful methods
module AllocatorUtils
  private
  # Execute cmd in current thread.
  # Returns Process::Status or throws SystemCallError.
  def run_cmd(cmd)
    @logger.info("running command: #{cmd}") if defined? @logger
    result = `#{cmd}`
    exit_code = $?
    @logger.info("result of '#{cmd}': #{result.strip}, exit code: #{exit_code}") if defined? @logger
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
        @logger.error "can't execute '#{cmd}', cause: #{e.message}" if defined? @logger
      end
    end
    false
  end
  
  # Creating subdirectory in current directory, if not exists yet.
  # Raises Exception if fails.
  def create_directory(name)
    begin
      Dir.mkdir(name)
    rescue Errno::EEXIST
      raise if not File.directory?(name)
    end
  end

  # Uploads files to remote server
  def upload_files(source, target, options = {})
    cmd = "ssh #{options[:user]}@#{options[:host]} mkdir -p #{options[:root_dir]}"
    if not run_cmd(cmd).first.success?
      @logger.error("can't create remote directory")
      return false
    end
    
    source = Array(source).join(' ')
    cmd = "scp -r -C #{source} #{options[:user]}@#{options[:host]}:#{target}"
    result = run_cmd(cmd)
    if result.first.success?
      @logger.info("files were sucessfully uploaded")
    else
      @logger.error("failed to upload files")
    end
    return result.first.success?
  end
end
