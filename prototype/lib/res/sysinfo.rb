# Author: Yuri Gorshenin

$:.unshift File.dirname(__FILE__)

require 'resource_parser'

# Class obtains information about current operation
# system, i.e. ram, cpu, cpu_num, disk and so on
class SysInfo
  MEMINFO = '/proc/meminfo'
  CPUINFO = '/proc/cpuinfo'
  
  # Returns hash { :ram, :cpu, :num_cpu, :disk }
  def self.get_info
    ram, cpu, disk = get_ram_info, get_cpu_info, get_disk_info
    return {}.merge(ram).merge(cpu).merge(disk)
  end

  # Returns hash { :ram, :cpu, :num_cpu, :disk }
  def self.read_info(path)
    attributes = {}
    File.open(path, 'r') do |file|
      file.each do |line|
        key, value = line.strip.split(/\s*:\s*/).map { |v| v.downcase }
        case key
        when 'ram' then attributes[:ram] = ResourceParser.parse_m(value)
        when 'cpu' then attributes[:cpu] = ResourceParser.parse_m(value)
        when 'num_cpu' then attributes[:num_cpu] = value.to_i
        when 'disk' then attributes[:disk] = ResourceParser.parse_m(value)
        end
      end
    end
    attributes
  end

  # Gets information about ram
  def self.get_ram_info
    result = {}
    File.open(MEMINFO, 'r') do |file|
      file.each do |line|
        key, value = line.strip.split(/\s*:\s*/).map { |v| v.downcase }
        result[:ram] = Resource_Parser.parse_m(value) if key == 'memfree'
      end
    end
    result
  end

  def self.get_cpu_info
    result = {}
    File.open(CPUINFO, 'r') do |file|
      file.each do |line|
        key, value = line.strip.split(/\s*:\s*/).map { |v| v.downcase }
        case key
        when 'processor' then result[:num_cpu] = value.to_i + 1
        when 'cpu mhz' then result[:cpu] = value.to_i
        end
      end
    end
    result
  end

  def self.get_disk_info
    # TO DO: get available disk space
  end
end
