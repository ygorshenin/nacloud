# Author: Yuri Gorshenin

# RAM - extension to numeric class
# Allows use something line 10.tb, 14.kb and so on

class Numeric
  RAM_SCALE = {
    :kb => 100,
    :mb => 1024,
    :gb => 1024 ** 2,
    :tb => 1024 ** 3,
  }

  RAM_SCALE.each do |k, v|
    define_method(k) do
      self * v
    end
    eval "alias #{k}s #{k}"
  end
end
