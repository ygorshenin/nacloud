# Author: Yuri Gorshenin

# Class represents key storage, for each key there are id, which
# is ordered number of that key
class KeyId
  def initialize
    @key2id, @id2key = {}, []
  end

  def get_id(key)
    unless @key2id.has_key?(key)
      id = size
      @key2id[key] = id
      @id2key[id] = key
    end
    @key2id[key]
  end

  def get_key(id)
    @id2key[id]
  end
  
  def clear
    @key2id, @id2key = {}, []
  end

  def size
    @key2id.size
  end
end
