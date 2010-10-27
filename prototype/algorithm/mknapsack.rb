# Author: Yuri Gorshenin

require 'matrix'

# Class represent algorithm for solving 0/1 multiple knapsack problem
# by an evolutionart lagrangian method (read Yourim Yoon, Yong-Hyuk Kim, Byung-Ro Moon)
# 
# One may solve one instance of problem by calling solve method
# solve(values, requirements, bounds)
# -- values is the array of costs of corresponding items
# -- requirements is the two-dimensional array where each row is requirements for each item
# -- bounds is the bounds of knapsack

class MultipleKnapsack
  def solve(values, requirements, bounds)
    requirements.each_index do |r, i|
      r.each_index do |j|
        if r[j] > bounds[j]
          values[i] = 0
          break
        end
      end
    end
    
    @v, @w, @b = Matrix[values].t, Matrix[*requirements].t, Matrix[bounds].t
    @n, @m = values.size, bounds.size

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
      return mstar if satisfy(xstar)
    end
  end
end
