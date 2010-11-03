#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'lib/algo/glpk_mdmknapsack.rb'
require 'lib/ext/core_ext'
require 'test/unit'

class TestGLPKMDMultipleKnapsack < Test::Unit::TestCase
  DELTA = 1e-6
  
  def setup
    @algo = GLPKMDMultipleKnapsack.new
  end

  def test_empty
    input = [[], [], []]
    result = @algo.solve(*input)
    consistent?(input[0], input[1], input[2], result)
    assert_result([0, []], result)

    input = [[], [], [[], [], []]]
    result = @algo.solve(*input)
    consistent?(input[0], input[1], input[2], result)
    assert_result([0, []], result)

    input = [[10, 20, 30], [[], [], []], [[]]]
    result = @algo.solve(*input)
    consistent?(input[0], input[1], input[2], result)
    must_be(60, result.first, "test empty")
  end

  def test_zero_requirements
    n, m, k = 10, 20, 30
    input = [(0 ... n).to_a, Array.new(n) { Array.new(m, 0) }, Array.new(k) { Array.new(m, 1) }]
    result = @algo.solve(*input)
    consistent?(input[0], input[1], input[2], result)
    must_be((0 ... n).to_a.sum, result.first, "zero requirements")
  end

  def test_very_simple
    input = [[6, 7, 12, 13, 1], [[4, 6], [5, 5], [6, 4], [5, 5], [1, 1]], [[10, 10], [10, 10]]]
    result = @algo.solve(*input)
    consistent?(input[0], input[1], input[2], result)
    must_be(38, result.first, "test very simple")
  end

  def test_simple
    n, m = 50, 4
    k = n
    values = (0 ... n).to_a
    requirements = Array.new(n) { |i| Array.new(m, i) }.shuffle
    bounds = Array.new(k) { |i| Array.new(m, i) }.shuffle
    result = @algo.solve(values, requirements, bounds)
    consistent?(values, requirements, bounds, result)
    must_be(values.sum, result.first, "test simple")
  end

  def test_float_small
    input = [[6.1, 7.15, 12.3, 13.76, 1], [[4, 6], [5, 5], [6, 4], [5, 5], [1, 1]], [[10, 10], [10, 10]]]
    result = @algo.solve(*input)
    consistent?(input[0], input[1], input[2], result)
    must_be(6.1 + 7.15 + 12.3 + 13.76, result.first, "test float small")
  end

  def consistent?(values, requirements, bounds, result)
    value, assignment = result
    if values.empty?
      assert_result([0, []], result)
    elsif bounds.empty?
      assert_result([0, [false] * values.size], result)
    elsif not bounds.first.empty?
      used = Array.new(bounds.size) { Array.new(bounds.first.size, 0) }
      assignment.each_with_index do |k, i|
        next unless k
        value -= values[i]
        requirements[i].each_index { |j| used[k][j] += requirements[i][j] }
      end
      assert_in_delta(0, value, DELTA)
      used.each_with_index do |kit, k|
        kit.each_with_index { |r, j| assert(r <= bounds[k][j] + DELTA) }
      end
    end
  end

  def assert_result(expected, result)
    assert_in_delta(expected.first, result.first, DELTA)
    assert_equal(expected.last, result.last)
  end

  def must_be(expected, result, msg = "")
    percent = result.to_f / expected * 100
    STDERR.printf("%s: ", msg) if not msg.empty?
    STDERR.printf("%.2f percent from optimal", percent)
  end  
end
