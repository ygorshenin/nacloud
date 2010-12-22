# Author: Yuri Gorshenin

require 'fileutils'

# Class contains several common useful methods
class AllocatorUtils
  # Execute cmd in current thread.
  # Returns Process::Status or throws SystemCallError.
  def self.run_cmd(cmd)
    result = `#{cmd}`
    $?
  end
  
  # Tries to run cmd at most reruns times.
  # Returns [success boolean flag, message]
  def self.run_cmd_times(cmd, reruns)
    ok, os = false, StringIO.new
    reruns.times do
      begin
        if run_cmd(cmd).success?
          ok = true
          break
        end
      rescue Exception => e
        os.puts e.message
      end
    end
    [ok, os.string]
  end

  # Task must have :user, :name and :replica keys
  def self.get_task_key(task)
    task[:user] + '.' + task[:name] + '.' + task[:replica].to_s
  end

  def self.get_task_home(base, task)
    File.join(base, task[:user], task[:name] + '.' + task[:replica].to_s)    
  end

  # Options must have :host and :port keys
  def self.get_uri(task)
    "druby://#{task[:host]}:#{task[:port]}"
  end
end
