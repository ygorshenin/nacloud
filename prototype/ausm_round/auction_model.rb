require 'lib/core_ext'
require 'algo/glpk_mdmknapsack'

class AUSMModelRound
  attr_reader :allocation

  def initialize(suppiers, algo=GLPKMDMK.new)
    # @suppliers maps {:supplier_id => supplier} @allocation maps
    # {:supplier_id => {:demander_id => {:demander => demander, :bid
    # => bid}}} --- all demanders in possible allocation to this
    # supplier @algo is a realization of knapsack algorithm

    
    @suppiers, @allocation, @algo = {}, {}, algo
    suppiers.each do |supplier|
      @suppiers[supplier.get_id] = supplier
      @allocation[supplier.get_id] = {}
    end

    # in_allocation maps {:demander_id => true }
    @in_allocation = {}
  end

  def in_allocation?(demander)
    @in_allocation.has_key
  end
end
