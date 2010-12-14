class Array
  def sum
    self.inject { |r, v| r + v }
  end

  def second
    self[1]
  end
end
