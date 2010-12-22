# Author: Yuri Gorshenin

# Class contains several common useful methods
class AllocatorUtils
  def self.get_task_key(task)
    task[:user] + '.' + task[:name] + '.' + task[:replica].to_s
  end

  def self.get_task_home(base, task)
    File.join(base, task[:user], task[:name] + '.' + task[:replica].to_s)    
  end

  def self.get_uri(task)
    "druby://#{task[:host]}:#{task[:port]}"
  end
end
