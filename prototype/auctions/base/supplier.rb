# Author: Yuri Gorshenin

# Supplier class
# Contains only quantities of available resources (in dimensions) and
# lower costs (minimum cost for each resource type) in some currency

# for instance, if we would create Supplier which represents simple client desktop machine
# with 2 MHz CPU and 1024 MB RAM,
# We should create Supplier.new({ :cpu => 2.mhz, :ram => 1024.mb }, { :cpu => 0, :ram => 0 })

class Supplier
  attr_reader :dimensions, :lower_costs
  
  def initialize(id, dimensions, lower_costs)
    @dimensions = dimensions
    @lower_costs = lower_costs
    @supplier_id = id
  end

  def get_id
    @supplier_id
  end

  def acceptible_bid? (bid)
    if (bid[:dimensions] <=> @dimensions) < 1
      total_cost = 0
      bid[:dimensions].each_with_index { |d, i| total_cost += @lower_costs[i] * d }
      return bid[:pay] >= total_cost
    end
    return false
  end

  def to_s
    "id: #{get_id}, dimensions: #{dimensions.inspect}, lower costs: #{lower_costs.inspect}"
  end
end
