require 'lib/core_ext'
require 'algo/mknapsack'
require 'algo/rknapsack'

class AUSMModel
  attr_reader :allocation
  
  def initialize(suppliers, algo = RandomMultipleKnapsack.new)
    @suppliers, @allocation, @algo = {}, [], algo
    suppliers.each { |supplier| @suppliers[supplier.get_id] = supplier }
  end

  def in_allocation?(demander)
    @allocation.find { |pair| pair[:demander] == demander }
  end

  def try_bid(demander, bid)
    supplier_id = bid[:supplier_id]
    supplier = @suppliers[supplier_id]
    
    if supplier.acceptible_bid?(bid)
      was_here = @allocation.find_all { |pair| pair[:bid][:supplier_id] == supplier_id }
      was_paid = was_here.inject(0) { |r, pair| r + pair[:bid][:pay] }
      
      d = supplier.dimensions.size
      
      bounds = Array.new(d) { |i| supplier.dimensions[i] - bid[:dimensions][i] }
      requirements = was_here.collect { |pair| pair[:bid][:dimensions] }
      values = was_here.collect { |pair| pair[:bid][:pay] }

      result = @algo.solve(values, requirements, bounds)

      if result.first + bid[:pay] > was_paid
        @allocation.delete_if { |pair| pair[:bid][:supplier_id] == supplier_id }
        result[1].each_with_index { |r, i| @allocation.push(was_here[i]) if r }
        @allocation.push({:demander => demander, :bid => bid })
        return :accepted
      end
    end
    return :rejected
  end
end
