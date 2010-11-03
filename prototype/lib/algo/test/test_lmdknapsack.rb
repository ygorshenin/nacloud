#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'lib/algo/lmdknapsack'
require 'lib/algo/test/test_module'
require 'test/unit'

class TestMultipleKnapsack < Test::Unit::TestCase
  include SimpleKnapsackTests
  
  def setup
    @algo = LagrangianMDKnapsack.new
  end
end
