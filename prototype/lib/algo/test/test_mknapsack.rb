require 'test/unit'
require 'algo/mknapsack'
require 'algo/test/test_module'

class TestMultipleKnapsack < Test::Unit::TestCase
  include SimpleKnapsackTests
  
  def setup
    @algo = MultipleKnapsack.new
  end
end
