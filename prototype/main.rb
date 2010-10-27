require 'supplier'
require 'demander'
require 'auction_server'
require 'lib/core_ext'

SUPPLIERS = 20
DEMANDERS_A, DEMANDERS_B, DEMANDERS_C = 20, 20, 20

def get_percent(cur, best)
  sprintf("%.2f", cur.to_f / best * 100) + '%'
end

def simple_test
  suppliers = Array.new(SUPPLIERS) { |i| Supplier.new(i, [10.5, 10.5], [0, 0]) }
  demanders_a = Array.new(DEMANDERS_A) { |i| DummyDemander.new(i, [4, 6], 11, 1) }
  demanders_b = Array.new(DEMANDERS_B) { |i| DummyDemander.new(DEMANDERS_A + i, [6, 4], 11, 1) }
  demanders_c = Array.new(DEMANDERS_C) { |i| DummyDemander.new(DEMANDERS_A + DEMANDERS_B + i, [5, 5], 5, 1) }

  demanders = demanders_a + demanders_b + demanders_c
  
  auction = AUSMAuction.new(suppliers, demanders, :max_iterations => 400)
  allocation = auction.run_auction[:allocation]

  puts "final allocation:"

  allocation.sort_by { |pair| pair[:demander].get_id }.each { |pair| puts "demander: #{pair[:demander].get_id}, bid: #{pair[:bid].inspect}" }

  total_profit, total_utility = 0, 0
  optimal_profit, optimal_utility = 440, 540
  allocation.each do |pair|
    total_profit += pair[:bid][:pay]
    total_utility += pair[:demander].get_utility(pair[:bid])
  end
  puts "total profit: #{total_profit} (#{get_percent(total_profit, optimal_profit)} from optimal)"
  puts "total_utility: #{total_utility} (#{get_percent(total_utility, optimal_utility)} from optimal)"
end

simple_test
