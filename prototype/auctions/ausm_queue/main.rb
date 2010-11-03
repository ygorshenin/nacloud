#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'auctions/ausm_queue/auction_server'
require 'auctions/base/demander'
require 'auctions/base/supplier'
require 'lib/core_ext'

SUPPLIERS = 10
DEMANDERS_A, DEMANDERS_B, DEMANDERS_C = 5, 5, 10

def get_percent(cur, best)
  sprintf("%.2f", cur.to_f / best * 100) + '%'
end

def simple_test
  suppliers = Array.new(SUPPLIERS) { |i| Supplier.new('Lambda' + i.to_s, [10, 10], [0, 0]) }
  demanders_a = Array.new(DEMANDERS_A) { |i| DummyDemander.new('Alpha' + i.to_s, [4, 6], 10, 1, ['Lambda' + (2 * i).to_s, 'Lambda' + (2 * i + 1).to_s]) }
  demanders_b = Array.new(DEMANDERS_B) { |i| DummyDemander.new('Beta' + i.to_s, [6, 4], 10, 1, ['Lambda' + (2 * i).to_s, 'Lambda' + (2 * i + 1).to_s]) }
  demanders_c = Array.new(DEMANDERS_C) { |i| DummyDemander.new('Gamma' + i.to_s, [5, 5], 10, 1, ['Lambda' + ((i / 2) * 2).to_s, 'Lambda' + ((i / 2) * 2 + 1).to_s]) }

  demanders = demanders_a.shuffle + demanders_b.shuffle + demanders_c.shuffle
  
  auction = AUSMServerQueue.new(suppliers, demanders, :max_iterations => 100)
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
