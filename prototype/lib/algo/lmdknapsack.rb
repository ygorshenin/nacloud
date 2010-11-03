# Author: Yuri Gorshenin

require 'lib/ext/core_ext'
require 'matrix'

# Class represent algorithm for solving 0/1 multidimensional one-knapsack problem
# by an evolutionart lagrangian method (read Yourim Yoon, Yong-Hyuk Kim, Byung-Ro Moon)
# 
# One may solve one instance of problem by calling solve method
# solve(values, requirements, bounds)
# -- values is the array of costs of corresponding items
# -- requirements is the two-dimensional array where each row is requirements for each item
# -- bounds is the bounds of knapsack

class LagrangianMDKnapsack
  def solve(values, requirements, bounds)
    return [ 0, [] ] if values.empty?
    return [ values.sum, Array.new(values.size, true) ] if bounds.empty?

    @n, @m = values.size, bounds.size
    
    requirements.each_with_index do |r, i|
      r.each_index do |j|
        if r[j] > bounds[j]
          values[i] = 0
          break
        end
        r[j] = EPS / @n if r[j] == 0
      end
    end
    
    @v, @w, @b = Matrix[values].t, Matrix[*requirements].t, Matrix[bounds].t
    
    go
  end

  private
  
  EPS = 1e-6

  def lmmkp(coeff)
    limit = (@w.t * coeff)
    xstar = Matrix[Array.new(@n) { |i| @v[i, 0] > limit[i, 0] + EPS ? 1 : 0 }].t
    bstar = @w * xstar
    mstar = (@v.t * xstar)[0, 0]
    [ mstar, xstar, bstar ]
  end

  # Does x satisfies all conditions?
  def satisfy(x)
    (@b - @w * x).t.to_a.flatten.min + EPS >= 0.0
  end

  def go
    coeff, id, alpha = Array.new(@m, 0.0), (0 ... @n).to_a, Array.new(@n, 0.0)
    vcoeff = Matrix[coeff].t
    mstar, xstar, bstar = nil, nil, nil
    
    loop do
      k, limit, best = rand(@m), @v - @w.t * vcoeff, -1
      id.each do |i|
        alpha[i] = limit[i, 0] / @w[k, i]
        best = i if best == -1 or alpha[best] > alpha[i]
      end
      coeff[k] += alpha[best]
      vcoeff = Matrix[coeff].t
      id.delete(best)
      mstar, xstar, bstar = *lmmkp(Matrix[coeff].t)
      if satisfy(xstar)
        assignment = Array.new(@n) { |i| xstar[i, 0] == 1 }
        result = 0
        assignment.each_with_index { |v, i| result += @v[i, 0] if v }
        return [ result, assignment ]
      end
    end
  end
end
