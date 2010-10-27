require 'test/unit'
require 'algorithm/rknapsack'
require 'algorithm/test_module'

class TestRandomKnapsack < Test::Unit::TestCase
  include SimpleKnapsackTests
  
  def setup
    @algo = RandomMultipleKnapsack.new
  end
end
