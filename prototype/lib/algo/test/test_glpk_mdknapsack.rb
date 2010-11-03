#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'lib/algo/glpk_mdknapsack'
require 'lib/algo/test/test_module'
require 'test/unit'

class TestGLPKMultipleKnapsack < Test::Unit::TestCase
  include SimpleKnapsackTests
  
  def setup
    @algo = GLPKMDKnapsack.new
  end
end
