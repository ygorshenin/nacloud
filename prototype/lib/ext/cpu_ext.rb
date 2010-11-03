# Author: Yuri Gorshenin

# CPU - extension to numeric class
# Allows use something like 2.mhz, 4.ghz and so on

class Numeric
  CPU_SCALE = {
    :khz => 100,
    :mhz => 1000,
    :ghz => 1000000,
  }

  CPU_SCALE.each do |k, v|
    define_method(k) do
      self * v
    end
    eval "alias #{k}s #{k}"
  end
end
