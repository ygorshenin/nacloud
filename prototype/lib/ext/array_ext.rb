class Array
  def sum
    self.inject { |r, v| r + v }
  end
end
