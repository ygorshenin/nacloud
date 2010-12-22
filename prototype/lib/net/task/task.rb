# Author: Yuri Gorshenin

require 'monitor'

# Class represents single task. User can start or stop task.
# task must contain home directory and binary/command description.
#
# This class is thread safe.
class Task
  include MonitorMixin
  
  attr_reader :status
  
  def initialize(task)
    @task, @status = task, :stopped
    
    @cmd = "cd #{@task[:home]};"
    if @task.has_key? :binary
      @cmd += './' + File.basename(@task[:binary])
    elsif @task.has_key? :command
      @cmd += @task[:command]
    end
  end

  # Access to task resources
  def resources
    @task[:resources]
  end

  # Starts task. Creates new process, all output is supressed.
  # Does nothing if task is already runned.
  def start
    return if @status == :runned
    
    @pid = fork do
      Process::setsid
      STDIN.reopen('/dev/null', 'r')
      STDOUT.reopen('/dev/null', 'w')
      STDERR.reopen('/dev/null', 'w')
      exec @cmd
    end
    @status = :runned
  end

  # Stops task.
  # Does nothing if task is already stopped.
  def stop
    return if @status == :stopped
    
    begin
      Process::kill('-TERM', @pid)
    rescue Exception => e
      STDERR.puts e
      STDERR.puts e.backtrace
    ensure
      @status = :stopped
    end
  end
end
