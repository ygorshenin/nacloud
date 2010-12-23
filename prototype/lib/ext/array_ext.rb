class Array
  def sum
    self.inject(0) { |r, v| r + v }
  end

  def second
    self[1]
  end
end
