#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'auctions/ausm_round/auction_server'
require 'auctions/ausm_round/demander'
require 'auctions/base/supplier'
require 'lib/core_ext'

SUPPLIERS = 10
DEMANDERS = 10

MAX_PAY, STEP = 10, 1

def get_percent(cur, best)
  sprintf("%.2f", cur.to_f / best * 100) + '%'
end

def simple_test
  suppliers = Array.new(SUPPLIERS) { |i| Supplier.new(i, [i + 1, i + 1], [0, 0]) }
  demanders = Array.new(DEMANDERS) { |i| DummyDemander.new(i, [i + 1, i + 1], MAX_PAY, STEP) }
  demanders.push(DummyDemander.new(DEMANDERS, [1, 1], MAX_PAY, STEP))
  
  suppliers.shuffle!
  demanders.shuffle!
  
  auction = AUSMServerRound.new(suppliers, demanders, :max_iterations => 5)
  allocation = auction.run_auction[:allocation]

  puts "final allocation:"

  allocation.each do |supplier_id, demanders|
    demanders.each do |demander_id, info|
      puts "supplier: #{supplier_id}, demander: #{demander_id}, bid: #{info[:bid].inspect}"
    end
  end

  total_profit, total_utility = 0, 0
  optimal_profit, optimal_utility = 100, 100
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
