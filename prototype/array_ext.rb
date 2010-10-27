class Array
  def shuffle
    sort_by { rand }
  end

  def shuffle!
    self.replace shuffle
  end

  def sum
    self.inject { |r, v| r + v }
  end
end
