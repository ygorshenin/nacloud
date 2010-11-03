require 'lib/core_ext'

module SimpleKnapsackTests
  DELTA = 1e-6
  MAX_VALUE = 10000
  MAX_BOUND = 10000
  
  def test_empty
    input = [[], [], [1, 2, 3]]
    result = @algo.solve(*input)
    consistent?(input[0], input[1], input[2], result)
    assert_result([0, []], result)

    input = [[], [], []]
    result = @algo.solve(*input)
    consistent?(input[0], input[1], input[2], result)
    assert_result([0, []], result)

    input = [[10, 20, 30], [[],[],[]],[]]
    result = @algo.solve(*input)
    consistent?(input[0], input[1], input[2], result)
    assert_result([60, [true] * 3], result)
  end

  def test_zero_requirements
    input = [(1 .. 10).to_a, Array.new(10) { Array.new(20, 0) }, Array.new(20, 1)]
    result = @algo.solve(*input)
    consistent?(input[0], input[1], input[2], result)
    must_be(result.first, (1 .. 10).to_a.sum, "zero requirements")
  end
  
  def test_very_simple
    input = [[11], [[10, 10]], [9, 10]]
    result = @algo.solve(*input)
    consistent?(input[0], input[1], input[2], result)
    assert_result([0, [false]], result)
  end

  def test_simple
    input = [[14, 5, 5, 5], [[30, 30], [11, 19], [1, 10], [18, 1]], [30, 30]]
    result = @algo.solve(*input)
    consistent?(input[0], input[1], input[2], result)
    must_be(result.first, 15, "test simple")
  end
  
  def test_no_solution
    n, m = 100, 10
    values = Array.new(n) { |i| i }
    bounds = Array.new(m) { MAX_BOUND - 1 }
    requirements = Array.new(n) { |i| Array.new(m) { |j| bounds[j] + 1 + i } }
    result = @algo.solve(values, requirements, bounds)
    consistent?(values, requirements, bounds, result)
    assert_result([0, Array.new(n, false)], result)
  end

  def test_random_no_solution
    n, m = 100, 20
    values = Array.new(n) { rand(MAX_VALUE) }
    bounds = Array.new(m) { rand(MAX_BOUND) }
    requirements = Array.new(n) { |i| Array.new(m) { |j| bounds[j] + 1 + rand(MAX_BOUND) } }
    result = @algo.solve(values, requirements, bounds)
    consistent?(values, requirements, bounds, result)
    assert_result([0, Array.new(n, false)], result)
  end

  def test_large
    n, m = 100, 10
    values = Array.new(n / 2, 1) + Array.new(n / 2, 2)
    values.shuffle!
    requirements = Array.new(n) { Array.new(m, 1) }
    bounds = Array.new(m, n / 2)
    result = @algo.solve(values, requirements, bounds)
    consistent?(values, requirements, bounds, result)
    must_be(result.first, 200, "test large")
  end

  def test_float_small
    values = [6.3, 7.1, 12.0]
    requirements = [[4, 6], [6, 4], [5, 5]]
    bounds = [10, 10]
    result = @algo.solve(values, requirements, bounds)
    consistent?(values, requirements, bounds, result)
    must_be(result.first, 13.4, "test float small")
  end
  
  def consistent?(values, requirements, bounds, result)
    value, assignment = result
    assert_equal(values.size, assignment.size)
    used = Array.new(bounds.size, 0)
    assignment.each_index do |index|
      if assignment[index]
        value -= values[index]
        requirements[index].each_with_index { |r, i| used[i] += r }
      end
    end
    assert_in_delta(0, value, DELTA)
    used.each_with_index { |r, i| assert(r <= bounds[i] + DELTA) }
  end

  def assert_result(expected, result)
    assert_in_delta(expected.first, result.first, DELTA)
    assert_equal(expected.last, result.last)
  end

  def must_be(result, correct, msg="")
    percent = result.to_f / correct * 100
    STDERR.printf("%s: ", msg) if not msg.empty?
    STDERR.printf("%.2f percent from optimal", percent)
  end
end
