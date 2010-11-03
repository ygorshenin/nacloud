# Author: Yuri Gorshenin

# Class represents dummy demander behavior. For each bid request,
# if it's first bid request or last bid was accepted, nothing is changed.
# Otherwise, raise pay.

class DummyDemander
  def initialize(id, dimensions, max_pay, step, suppliers_range = nil)
    @id, @dimensions = id, dimensions
    @max_pay, @step, @cur_pay = max_pay, step, 0
    @range = suppliers_range
  end

  def get_id
    @id
  end

  def get_bid(suppliers, info)
    return @last_bid if was_accepted(info.last)
    @last_bid = {
      :supplier_id => @range,
      :dimensions => @dimensions,
      :pay => @cur_pay,
    }
    @cur_pay += @step if @cur_pay + @step <= @max_pay
    @last_bid
  end

  def get_utility(bid)
    @max_pay - bid[:pay]
  end

  private

  # Checks, if that demander's bid was accepted previously
  def was_accepted(entry)
    return false unless entry
    entry[:allocation].each_value do |v|
      return true if v.has_key?(get_id)
    end
    false
  end
end
