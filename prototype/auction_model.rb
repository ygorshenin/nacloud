require 'lib/core_ext'
require 'algo/mknapsack'

class AUSMModel
  attr_reader :allocation
  
  def initialize(suppliers, algo=MultipleKnapsack.new)
    @suppliers, @allocation, @algo = {}, [], algo
    suppliers.each { |supplier| @suppliers[supplier.get_id] = supplier }
  end

  def in_allocation?(demander)
    @allocation.find { |pair| pair[:demander] == demander }
  end

  def try_bid(demander, bid)
    supplier_id = bid.get_supplier_id
    supplier = @suppliers[supplier_id]
    
    if supplier.acceptible_bid?(bid)
      was_here = @allocation.find_all { |pair| pair[:bid].get_supplier_id == supplier_id }
      was_paid = was_here.inject(0) { |r, pair| r + pair[:bid].pay }
      
      d = supplier.dimensions.size
      
      bounds = Array.new(d) { |i| supplier.dimensions[i] - bid.dimensions[i] }
      requirements = was_here.collect { |pair| pair[:bid].dimensions }
      values = was_here.collect { |pair| pair[:bid].pay }

      result = @algo.solve(bounds, requirements, values)
      if result.first > was_paid
        @allocation.delete_all { |pair| pair[:bid].get_supplier_id == supplier_id }
        result[1].each_with_index { |r, i| @allocation.push(was_here[i]) if r }
        @allocation.push({:demander => demander, :bid => bid })
        return :accepted
      end
    end
    return :rejected
  end
end
