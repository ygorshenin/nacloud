require 'test/unit'
require 'algo/glpk_mknapsack'
require 'algo/test/test_module'

class TestGLPKMultipleKnapsack < Test::Unit::TestCase
  include SimpleKnapsackTests
  
  def setup
    @algo = GLPKMultipleKnapsack.new
  end
end
