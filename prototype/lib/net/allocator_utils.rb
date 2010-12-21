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

  # Options must have :user, :name and :replica keys
  def self.get_task_key(options)
    options[:user] + '.' + options[:name] + '.' + options[:replica].to_s
  end

  # Options must have :host and :port keys
  def self.get_uri(options)
    "druby://#{options[:host]}:#{options[:port]}"
  end
end
