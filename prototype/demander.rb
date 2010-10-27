# Author: Yuri Gorhshenin

# Class represents dummy demander behavior.
# For each bid request, randomly selects supplier and try to increase last pay, until budget is exhausted
# If all suppliers are processed, tries to bid to random supplier with max_pay
# This demander doesn't use any info about suppliers or info

class DummyDemander
  def initialize(dimensions, min_pay, max_pay, step)
    @dimensions = dimensions
    
    @min_pay, @max_pay = min_pay, max_pay
    @step = step
    @cur_pay = {}
  end

  # get_bid called if and only if our previous bids was rejected
  def get_bid(suppliers, info)
    cur_supplier = rand(suppliers.size)
    if @cur_pay[cur_supplier]
      @cur_pay[cur_supplier] += @step if @cur_pay[cur_supplier] < @max_pay
    else
      @cur_pay[cur_supplier] = @min_pay
    end
    { :supplier_id => cur_supplier, :dimensions => @dimensions, :pay => @cur_pay[cur_supplier] }
  end

  def get_utility(bid)
    @max_pay - bid[:pay]
  end
end
