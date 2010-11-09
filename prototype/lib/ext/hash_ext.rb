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
end
