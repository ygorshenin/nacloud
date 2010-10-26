# Author: Yuri Gorshenin

require 'core_ext'

# Supplier class
# Contains only quantities of available resources (in dimensions) and
# lower costs (minimum cost for each resource type) in some currency

# for instance, if we would create Supplier which represents simple client desktop machine
# with 2 MHz CPU and 1024 MB RAM,
# We should create Supplier.new({ :cpu => 2.mhz, :ram => 1024.mb }, { :cpu => 0, :ram => 0 })

class Supplier
  attr_reader :dimensions, :lower_costs
  
  def initialize(dimensions, lower_costs)
    @dimensions = dimensions
    @lower_costs = lower_costs
  end
end
