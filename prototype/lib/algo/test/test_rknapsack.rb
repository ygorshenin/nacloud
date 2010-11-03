require 'test/unit'
require 'algo/rknapsack'
require 'algo/test/test_module'

class TestRandomKnapsack < Test::Unit::TestCase
  include SimpleKnapsackTests
  
  def setup
    @algo = RandomMultipleKnapsack.new
  end
end
