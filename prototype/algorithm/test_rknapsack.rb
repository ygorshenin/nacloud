require 'test/unit'
require 'rknapsack'

class TestRandomKnapsack < Test::Unit::TestCase
  MAX_VALUE = 10000
  MAX_BOUND = 10000
  
  def setup
    @algo = RandomMultipleKnapsack.new
  end

  def test_empty
    input = [[], [], [1, 2, 3]]
    result = @algo.solve(*input)
    consistent(input[0], input[1], input[2], result)
    assert_equal(result[0], 0)
    assert_equal(result[1], [])

    input = [[], [], []]
    result = @algo.solve(*input)
    consistent(input[0], input[1], input[2], result)
    assert_equal(result[0], 0)
    assert_equal(result[1], [])

    input = [[10, 20, 30], [[],[],[]],[]]
    result = @algo.solve(*input)
    consistent(input[0], input[1], input[2], result)
    assert_equal(result[0], 60)
    assert_equal(result[1], [true, true, true])
  end

  def test_very_simple
    input = [[11], [[10, 10]], [9, 10]]
    result = @algo.solve(*input)
    consistent(input[0], input[1], input[2], result)
    assert_equal(result[0], 0)
    assert_equal(result[1], [ false ])
  end

  def test_simple
    input = [[14, 5, 5, 5], [[30, 30], [11, 19], [1, 10], [18, 1]], [30, 30]]
    result = @algo.solve(*input)
    consistent(input[0], input[1], input[2], result)
    assert_equal(result[0], 15)
    assert_equal(result[1], [ false, true, true, true ])
  end

  def test_no_solution
    n, m = 100, 10
    values = Array.new(n) { |i| i }
    bounds = Array.new(m) { MAX_BOUND - 1 }
    requirements = Array.new(n) { |i| Array.new(m) { |j| bounds[j] + 1 + i } }
    result = @algo.solve(values, requirements, bounds)
    consistent(values, requirements, bounds, result)
    assert_equal(result[0], 0)
    assert_equal(result[1], Array.new(n) { false })
  end

  def test_random_no_solution
    n, m = 100, 20
    values = Array.new(n) { rand(MAX_VALUE) }
    bounds = Array.new(m) { rand(MAX_BOUND) }
    requirements = Array.new(n) { |i| Array.new(m) { |j| bounds[j] + 1 + rand(MAX_BOUND) } }
    result = @algo.solve(values, requirements, bounds)
    consistent(values, requirements, bounds, result)
    assert_equal(result[0], 0)
    assert_equal(result[1], Array.new(n) { false })
  end

  def consistent(values, requirements, bounds, result)
    value, assignment = result
    n, m = values.size, bounds.size
    used = Array.new(m, 0)
    assignment.each_index do |index|
      if assignment[index]
        value -= values[index]
        requirements[index].each_with_index { |r, i| used[i] += r }
      end
    end
    assert_equal(value, 0)
    used.each_with_index { |r, i| assert(r <= bounds[i]) }
  end
end
