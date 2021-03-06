# Author: Yuri Gorshenin

require 'auctions/base/ausm_model.rb'
require 'lib/ext/core_ext'

class AUSMModelQueue
  include AUSMModel
  
  def try_bid(demander, bid)
    Array(bid[:supplier_id]).each do |supplier_id|
      supplier = @suppliers[supplier_id]
      if supplier and supplier.acceptible_bid?(bid) and can_add_without_replacement?(supplier, bid)
        add_to_allocation(supplier, demander, bid)
        return :accepted
      end
    end
    
    Array(bid[:supplier_id]).each do |supplier_id|
      supplier = @suppliers[supplier_id]
      return :accepted if supplier and supplier.acceptible_bid?(bid) and
        try_replace(supplier, demander, bid) == :accepted
    end
    return :rejected
  end

  private

  # Tries to replace some allocated bids according to auction's rules.
  # WARNING: doesn't verifies basic costs limitation on bid and bid dimensions
  def try_replace(supplier, demander, bid)
    was_here = get_allocated_to_supplier(supplier)
    was_paid = was_here.inject(0) { |r, item| r + item[:bid][:pay] }
    
    d = supplier.dimensions.size
    
    bounds = Array.new(d) { |i| supplier.dimensions[i] - bid[:dimensions][i] }
    requirements = was_here.collect { |item| item[:bid][:dimensions] }
    values = was_here.collect { |item| item[:bid][:pay] }

    result = @algo.solve(values, requirements, bounds)

    if result.first + bid[:pay] > was_paid
      to_delete = []
      result[1].each_with_index { |r, i| to_delete.push(was_here[i][:demander]) unless r }
      delete_from_allocation(supplier, to_delete)
      add_to_allocation(supplier, demander, bid)
      return :accepted
    end
    return :rejected
  end

  # Verifies if there are enough space in suppliers's good to add that
  # bid without replacement.  WARNING: doesn't verifies basic costs
  # limitation
  def can_add_without_replacement?(supplier, bid)
    return false unless supplier.acceptible_bid?(bid)

    # gets two-dimensional array of bid's requirements
    requirements = get_allocated_to_supplier(supplier).collect { |item| item[:bid][:dimensions] }.push(bid[:dimensions])
    
    # creates array, represends used space for each dimension
    used_space = [0] * supplier.dimensions.size
    
    # calculate used space according to allocated bids
    used_space = used_space.zip(*requirements).map { |v| v.sum }
    used_space.each_index do |i|
      return false if used_space[i] > supplier.dimensions[i]
    end
    return true
  end

  # Gets all bids, allocated to that supplier
  def get_allocated_to_supplier(supplier)
    @allocation[supplier.get_id].values
  end

  # Deletes array of demanders (or single demander) from allocation to
  # this supplier
  def delete_from_allocation(supplier, demanders)
    Array(demanders).each do |demander|
      @allocation[supplier.get_id].delete(demander.get_id)
      @in_allocation.delete(demander.get_id)
    end
  end

  # Adds one demander to potential allocation of this supplier
  def add_to_allocation(supplier, demander, bid)
    @allocation[supplier.get_id][demander.get_id] = { :demander => demander, :bid => bid }
    @in_allocation[demander.get_id] = true
  end
end
