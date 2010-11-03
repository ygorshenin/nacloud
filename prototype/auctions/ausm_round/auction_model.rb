# Author: Yuri Gorshenin

require 'auctions/base/ausm_model'
require 'lib/keyid'

class AUSMModelRound
  include AUSMModel

  # WARNING: this method doesn't use lower costs limitations and
  # demanders preferences
  # bids is an array of hashes { :demander => demander, :bid => bid }
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

    preferences = get_all_preferences(suppliers_order, demanders_order, bids)

    result = @algo.solve(values, requirements, bounds, preferences)

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

  private

  # suppliers_order is a KeyId object, which helps transform arbitrary
  # keys to integer values and vice versa.
  # demanders_order has the same semantics.
  # Bids is an array of hashes { :demander => demander, :bid => bid }
  def get_all_preferences(suppliers_order, demanders_order, bids)
    preferences = Array.new(demanders_order.size) { Array.new(suppliers_order.size, 0) }
    bids.each do |h|
      demander, bid = h[:demander], h[:bid]
      indexes = get_preferences(demander, bid).map { |supplier_id| suppliers_order.get_id(supplier_id) }
      row = preferences[demanders_order.get_id(demander.get_id)]
      indexes.each { |i| row[i] = 1 }
    end
    # If really there are no preferences
    return nil if preferences.flatten.uniq == [1]
    return preferences
  end

  def get_preferences(demander, bid)
    Array(bid[:supplier_id] || @suppliers.keys).find_all { |supplier_id| @suppliers[supplier_id].acceptible_bid?(bid) }
  end
end
