# Author: Yuri Gorshenin

require 'lib/ext/core_ext'
require 'matrix'

# Random Multidimentional One-Knapsack algorithm.
# Stops after fixed number of iterations.
# On each iteration tries random permutation of items.
class RandomMDKnapsack
  def initialize(options={})
    @options = {
      :max_iterations => 10000
    }.merge(options)
  end

  
  def solve(values, requirements, bounds)
    n, m = values.size, bounds.size
    order, used = (0 ... n).to_a, Array.new(m, 0)
    best, assignment = 0, Array.new(n, false)
    
    @options[:max_iterations].times do
      used.fill(0)
      order.shuffle!
      value, cur_assignment = 0, Array.new(n, false)
      order.each do |index|
        ok = true
        requirements[index].each_with_index do |r, i|
          if used[i] + r > bounds[i]
            ok = false
            break
          end
        end
        if ok
          requirements[index].each_with_index { |r, i| used[i] += r }
          value += values[index]
          cur_assignment[index] = true
        end
      end
      if value > best
        best = value
        assignment = cur_assignment
      end
    end
    return [ best, assignment ]
  end
end
