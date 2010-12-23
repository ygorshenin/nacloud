# Author: Yuri Gorshenin

# Class represents simple resource manager.
# Can decide whether or not it is possible to
# run task with some resource usage.
#
# This class isn't thread safe.
class ResourceManager
  INITIAL_USAGE = {
    :ram => 0, # initially all ram is free
    :disk => 0, # initially all disk is free
  }

  # If some job doesn't use some resource,
  # we can place any number of replicas,
  # but this is natural limit.
  INFINITY_TASKS = 1000000000
  
  def initialize(resources)
    @resources, @usage = resources, INITIAL_USAGE
  end

  # Is it possible to add task with that resources usage?
  def available?(resources)
    ram = (@usage[:ram] + resources[:ram] <= @resources[:ram])
    disk = (@usage[:disk] + resources[:disk] <= @resources[:disk])
    ram and disk
  end

  # How many replicas of tasks with that resource usage it is possible to add?
  def num_available?(resources)
    # If there are no available resources for one task...
    return 0 unless available?(resources)
    by_ram = (resources[:ram] == 0 ? INFINITY_TASKS : (@resources[:ram] - @usage[:ram]) / resources[:ram])
    by_disk = (resources[:disk] == 0 ? INFINITY_TASKS : (@resources[:disk] - @usage[:disk]) / resources[:disk])
    min(by_ram, by_disk)
  end

  # Allocate resources, without any checking.
  def allocate(resources)
    @usage[:ram] += resources[:ram]
    @usage[:disk] += resources[:disk]
  end

  # Deallocate resources, without any checking.
  def deallocate(resources)
    @usage[:ram] -= resources[:ram]
    @usage[:disk] -= resources[:disk]
  end

  private

  def min(a, b)
    a < b ? a : b
  end

  def max(a, b)
    a > b ? a : b
  end
end
