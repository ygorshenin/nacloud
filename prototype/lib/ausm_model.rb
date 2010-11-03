module AUSMModel
  attr_reader :allocation

  def initialize(suppliers, algo)
    # @suppliers maps {:supplier_id => supplier} @allocation maps
    # {:supplier_id => {:demander_id => {:demander => demander, :bid
    # => bid}}} --- all demanders in possible allocation to this
    # supplier @algo is a realization of knapsack algorithm
    
    @suppliers, @allocation, @algo = {}, {}, algo
    suppliers.each do |supplier|
      @suppliers[supplier.get_id] = supplier
      @allocation[supplier.get_id] = {}
    end

    # in_allocation maps {:demander_id => true}
    @in_allocation = {}
  end

  # Vefifies is that demander in last potential allocation
  def in_allocation?(demander)
    @in_allocation.has_key?(demander.get_id)
  end
end
