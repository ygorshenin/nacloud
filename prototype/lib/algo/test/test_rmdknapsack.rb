#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'lib/algo/rmdknapsack'
require 'lib/algo/test/test_module'
require 'test/unit'

class TestRandomKnapsack < Test::Unit::TestCase
  include SimpleKnapsackTests
  
  def setup
    @algo = RandomMDKnapsack.new
  end
end
