# Author: Yuri Gorhshenin

# Class represents dummy demander behavior.  For each bid request,
# randomly selects supplier and try to increase last pay, until budget
# is exhausted. If all suppliers are processed, tries to bid to random
# supplier with max_pay. This demander doesn't use any info about
# suppliers or info.
# suppliers_range is a list of preferable suppliers (but it may be single value).


class DummyDemander
  def initialize(id, dimensions, max_pay, step, suppliers_range)
    @id, @dimensions = id, dimensions
    
    @max_pay, @step, @cur_pay = max_pay, step, 0
    @range = suppliers_range
  end

  def get_id
    @id
  end

  # get_bid called if and only if our previous bids was rejected
  def get_bid(suppliers, info)
    result = { :supplier_id => @range, :dimensions => @dimensions, :pay => @cur_pay }
    @cur_pay += @step if @cur_pay < @max_pay
    result
  end

  def get_utility(bid)
    @max_pay - bid[:pay]
  end
end
