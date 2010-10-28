require 'supplier'
require 'demander'
require 'auction_server'
require 'lib/core_ext'

SUPPLIERS = 10
DEMANDERS_A, DEMANDERS_B, DEMANDERS_C = 5, 5, 10

def get_percent(cur, best)
  sprintf("%.2f", cur.to_f / best * 100) + '%'
end

def simple_test
  suppliers = Array.new(SUPPLIERS) { |i| Supplier.new(i, [10, 10], [0, 0]) }
  demanders_a = Array.new(DEMANDERS_A) { |i| DummyDemander.new(i, [4, 6], 10, 1, [2 * i, 2 * i + 1]) }
  demanders_b = Array.new(DEMANDERS_B) { |i| DummyDemander.new(DEMANDERS_A + i, [6, 4], 10, 1, [2 * i, 2 * i + 1]) }
  demanders_c = Array.new(DEMANDERS_C) { |i| DummyDemander.new(DEMANDERS_A + DEMANDERS_B + i, [5, 5], 10, 1, [(i / 2) * 2, (i / 2) * 2 + 1]) }

  # demanders_a = Array.new(DEMANDERS_A) { |i| DummyDemander.new(i, [4, 6], 10, 1, (0 ... SUPPLIERS).to_a) }
  # demanders_b = Array.new(DEMANDERS_B) { |i| DummyDemander.new(DEMANDERS_A + i, [6, 4], 10, 1, (0 ... SUPPLIERS).to_a) }
  # demanders_c = Array.new(DEMANDERS_C) { |i| DummyDemander.new(DEMANDERS_A + DEMANDERS_B + i, [5, 5], 10, 1, (0 ... SUPPLIERS).to_a) }
  
  demanders = demanders_a + demanders_b + demanders_c
  
  auction = AUSMAuction.new(suppliers, demanders, :max_iterations => 100)
  allocation = auction.run_auction[:allocation]

  puts "final allocation:"

  allocation.each do |supplier_id, demanders|
    demanders.each do |demander_id, info|
      puts "supplier: #{supplier_id}, demander: #{demander_id}, bid: #{info[:bid].inspect}"
    end
  end

  total_profit, total_utility = 0, 0
  optimal_profit, optimal_utility = 200, 200
  allocation.each do |supplier_id, demanders|
    demanders.each do |demander_id, info|
     total_profit += info[:bid][:pay]
      total_utility += info[:demander].get_utility(info[:bid])
    end
  end
  puts "total profit: #{total_profit} (#{get_percent(total_profit, optimal_profit)} from optimal)"
  puts "total_utility: #{total_utility} (#{get_percent(total_utility, optimal_utility)} from optimal)"
end

simple_test
