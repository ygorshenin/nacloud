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
      base, kind = $`.to_i, $&[0, 1]
      return base * HASH[kind]
    else
      return size.to_i
    end
  end

  # This code adds methods like parse_b, parse_h, parse_k and so on,
  # which returns floor(parse(size) / 2 ** power)
  class << self
    PREFIXES.zip(POWERS).each do |prefix, power|
      define_method("parse_#{prefix}") do |size|
        parse(size) / power
      end
    end
  end
end

# Class obtains information about machine's RAM
class SysInfoRAM
  MEMINFO = '/proc/meminfo'

  # Returns hash { :ram_total, :ram_free }, where values in Mb
  def self.get_ram_info
    result = {}
    File.open(MEMINFO, 'r') do |file|
      file.each do |line|
        key, value = line.strip.split(/\s*:\s*/).map { |v| v.downcase }
        case key
        when 'memtotal' then result[:ram_total] = ResourceParser.parse_k(value)
        when 'memfree' then result[:ram_free] = ResourceParser.parse_k(value)
        end
      end
    end
    result
  end
end

# Class obtains information about machine's CPU
class SysInfoCPU
  CPUINFO = '/proc/cpuinfo'

  # Returns hash { :cpu_num, :cpu }, where values in Mz
  def self.get_cpu_info
    result = {}
    File.open(CPUINFO, 'r') do |file|
      file.each do |line|
        key, value = line.strip.split(/\s*:\s*/).map { |v| v.downcase }
        case key
        when 'processor' then result[:cpu_num] = value.to_i + 1
        when 'cpu mhz' then result[:cpu] = value.to_f
        end
      end
    end
    result
  end
end


# Class obtains information about current operation
# system, i.e. ram, cpu, num_cpu, disk and so on
class SysInfo
  # Returns hash { :ram_free, :ram_total, :cpu, :cpu_num }
  def self.get_info
    ram, cpu = get_ram_info, get_cpu_info
    return {}.merge(ram).merge(cpu)
  end

  # Gets information about ram
  def self.get_ram_info
    SysInfoRAM.get_ram_info
  end

  def self.get_cpu_info
    SysInfoCPU.get_cpu_info
  end
end
