# Author: Yuri Gorshenin

require 'auctions/base/ausm_model'
require 'lib/keyid'

class AUSMModelRound
  include AUSMModel

  # WARNING: this method doesn't use lower costs limitations and
  # demanders preferences
  def allocate_bids(bids)
    demanders = {} # maps demander_id => { :demander => demander, :bid => bid }
    bids.each { |h| demanders[h[:demander].get_id] = h }

    demanders_order, suppliers_order = KeyId.new, KeyId.new

    values = Array.new(demanders.size)
    requirements = Array.new(demanders.size)
    bounds = Array.new(@suppliers.size)

    demanders.each do |k, v|
      values[demanders_order.get_id(k)] = v[:bid][:pay]
      requirements[demanders_order.get_id(k)] = v[:bid][:dimensions]
    end

    @suppliers.each do |k, v|
      bounds[suppliers_order.get_id(k)] = v.dimensions
    end

    result = @algo.solve(values, requirements, bounds)

    @allocation, @in_allocation = {}, {}
    result.last.each_with_index do |supplier_id, demander_id|
      next unless supplier_id
      
      demander_id = demanders_order.get_key(demander_id)
      supplier_id = suppliers_order.get_key(supplier_id)
      
      @allocation[supplier_id] ||= {}
      @allocation[supplier_id][demander_id] = demanders[demander_id]
      @in_allocation[demander_id] = true
    end
  end
end
