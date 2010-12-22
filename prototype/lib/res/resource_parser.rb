# Author: Yuri Gorshenin

class ResourceParser
  PREFIXES = %w(b h k m g t p e z y)
  POWERS = ([0] + 0.step(80, 10).to_a).map { |power| 2 ** power }
  HASH = PREFIXES.zip(POWERS).map{|prefix, power| {prefix => power}}.inject({}) {|r, h| r.merge(h)}

  # Parses strings, that contains integer and standart suffix (byte, kilobyte, megabyte or hz, mhz, ghz),
  # and returns value in basic unit (byte or hz)
  def self.parse(size)
    size = size.downcase.gsub(/\s+/, '')
    if size =~ /[a-z]+/
      base, kind = $`.to_f, $&[0, 1]
      return (base * HASH[kind]).to_i
    else
      return size.to_i
    end
  end

  # This code adds methods like parse_b, parse_h, parse_k and so on,
  # which returns floor(parse(size) / 2 ** power)
  class << self
    PREFIXES.zip(POWERS).each do |prefix, power|
      define_method("parse_#{prefix}") do |size|
        (parse(size).to_f / power).to_i
      end
    end
  end
end
