# Author: Yuri Gorshenin

require 'auctions/base/ausm_model'

class AUSMModelRound
  include AUSMModel

  # WARNING: this method doesn't use lower costs limitations and
  # demanders preferences
  def allocate_bids(bids)
    demanders = {}
    bids.each { |info| demanders[info[:demander].demander_id] = info }
    
    values = bids.collect { |info| info[:bid][:pay] }
    requirements = bids.collect { |info| info[:bid][:requirements] }
    bounds = @suppliers.collect { |supplier| supplier.dimensions }
    result = @algo.solve(values, requirements, bounds)

    @allocation, @in_allocation = {}, {}
    result.last.each_with_index do |supplier_id, demander_id|
      next unless supplier_id
      @allocation[supplier_id][demander_id] = demanders[demander_id]
      @in_allocation[demander_id] = true
    end
  end
end
