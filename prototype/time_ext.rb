# Author: Yuri Gorshenin

# Time - extension to numeric class
# Allows use something like 24.minutes, 10.seconds, 2.days and so on

class Numeric
  TIME_SCALE = {
    :second => 1.0,
    :minute => 60.0,
    :hour => 60 * 60.0,
    :day => 60 * 60 * 24.0,
    :month => 30 * 60 * 60 * 24.0,
  }

  TIME_SCALE.each do |k, v|
    define_method(k) do
      self * v
    end
    eval "alias #{k}s #{k}"
  end
end
