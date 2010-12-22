# Author: Yuri Gorshenin

$:.unshift File.dirname(__FILE__)
$:.unshift File.join(File.dirname(__FILE__), '..')

require 'allocator_utils'
require 'forwardable'
require 'monitor'
require 'task'
require 'task_exception'

# Pool of tasks. Supports resource control.
# This class is thread safe.
class TaskPool
  include MonitorMixin
  extend Forwardable

  def_delegators :@resource_manager, :available?, :num_available?

  def initialize(resource_manager)
    @resource_manager, @pool = resource_manager, {}
  end

  # Adds task. Allocates resources, but not start.
  # Raises TaskException, if task with the same signature already here.
  # No resource checking.
  def add(task)
    key = AllocatorUtils::get_task_key(task)
    raise TaskException.new("task with key #{key} already here") if @pool.has_key? key

    task = Task.new(task)
    @resource_manager.allocate(task.resources)
    @pool[key] = task
  end

  # Starts already added task.
  # If task already started, nothing is happened.
  # Raises TaskException, if no such task here.
  def start(task)
    key = AllocatorUtils::get_task_key(task)
    raise TaskException.new("here are no task with key #{key}") unless @pool.has_key? key
    @pool[key].start
  end

  # Stops already added task.
  # If task already stopped, nothing is happened.
  # Raises TaskException, if no such task here.
  def stop(task)
    key = AllocatorUtils::get_task_key(task)
    raise TaskException.new("here are no task with key #{key}") unless @pool.has_key? key
    @pool[key].stop    
  end

  # Deletes already added task (stop + deallocate).
  # Raises TaskException, if no such task here.
  def delete(task)
    key = AllocatorUtils::get_task_key(task)
    raise TaskException.new("here are no task with key #{key}") unless @pool.has_key? key
    task = @pool.delete(key)
    task.stop
    @resource_manager.deallocate(task.resources)
  end
end
