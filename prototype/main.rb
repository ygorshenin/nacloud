require 'supplier'
require 'demander'
require 'auction_server'

SUPPLIERS = 15
DEMANDERS_A, DEMANDERS_B, DEMANDERS_C = 10, 10, 20

def get_percent(cur, best)
  sprintf("%.2f", cur.to_f / best * 100) + '%'
end

def simple_test
  suppliers = Array.new(SUPPLIERS) { |i| Supplier.new(i, [10, 10], [0.01, 0.01]) }
  demanders_a = Array.new(DEMANDERS_A) { DummyDemander.new([4, 6], 0, 10, 1) }
  demanders_b = Array.new(DEMANDERS_B) { DummyDemander.new([6, 4], 0, 10, 1) }
  demanders_c = Array.new(DEMANDERS_C) { DummyDemander.new([5, 5], 0, 10, 1) }

  demanders = demanders_a + demanders_b + demanders_c
  
  auction = AUSMAuction.new(suppliers, demanders, :max_iterations => 200)
  allocation = auction.run_auction[:allocation]
  puts "final allocation:"
  allocation.each { |pair| puts pair[:bid].inspect }

  total_profit, total_utility = 0, 0
  optimal_profit, optimal_utility = 200, 200
  allocation.each do |pair|
    total_profit += pair[:bid][:pay]
    total_utility += pair[:demander].get_utility(pair[:bid])
  end
  puts "total profit: #{total_profit} (#{get_percent(total_profit, optimal_profit)} from optimal)"
  puts "total_utility: #{total_utility} (#{get_percent(total_utility, optimal_utility)} from optimal)"
end

simple_test
