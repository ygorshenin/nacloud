require 'test/unit'
require 'algorithm/mknapsack'
require 'algorithm/test_module'

class TestMultipleKnapsack < Test::Unit::TestCase
  include SimpleKnapsackTests
  
  def setup
    @algo = MultipleKnapsack.new
  end
end
