# Author: Yuri Gorshenin

# Class represents simple resource manager.
# Can decide whether or not it is possible to
# run task with some resource usage.
#
# This class isn't thread safe.
class ResourceManager
  INITIAL_USAGE = {
    :ram => 0,
  }

  INFINITY_TASKS = 1000000000
  
  def initialize(resources)
    @resources, @usage = resources, INITIAL_USAGE
  end

  # Is it possible to add task with that resources usage?
  def available?(resources)
    @usage[:ram] + resources[:ram] <= @resources[:ram]
  end

  # How many replicas of tasks with that resource usage it is possible to add?
  def num_available?(resources)
    return INFINITY_TASKS if resources[:ram] == 0
    return 0 unless available?(resources)
    return (@resources[:ram] - @usage[:ram]) / resources[:ram]
  end

  # Allocate resources, without any checking.
  def allocate(resources)
    @usage[:ram] += resources[:ram]
  end

  # Deallocate resources, without any checking.
  def deallocate(resources)
    @usage[:ram] -= resources[:ram]
  end
end
