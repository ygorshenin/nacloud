# Author: Yuri Gorshenin

# Extension to standart Hash class.
# Allows make all keys symbolic
class Hash
  def symbolize_keys!
    self.keys.each do |key|
      self[key.to_sym] = self.delete(key) unless key.is_a?(Symbol)
    end
    self
  end

  def symbolize_keys_recursive!
    symbolize_keys!
    self.each do |k, v|
      self[k] = v.symbolize_keys_recursive! if v.is_a?(Hash)
    end
    self
  end

  def recursive_merge!(other)
    other.each do |key, value|
      if self.has_key?(key) and self[key].is_a?(Hash) and value.is_a?(Hash)
        self[key].recursive_merge!(value)
      else
        self[key] = value
      end
    end
    self
  end

  def recursive_merge(other)
    result = self.dup
    other.each do |key, value|
      if result.has_key?(key) and result[key].is_a?(Hash) and value.is_a?(Hash)
        result[key] = result[key].recursive_merge(value)
      else
        result[key] = value
      end
    end
    result
  end

  def copy
    result = {}
    self.each do |key, value|
      case value
      when Hash
        result[key] = value.copy
      when Array
        result[key] = value.dup
      when String
        result[key] = value.dup
      else
        result[key] = value
      end
    end
    result
  end
end
