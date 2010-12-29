class Array
  def sum
    self.inject(0) { |r, v| r + v }
  end

  def second
    self[1]
  end

  # Process values in parallel.
  # Block must write all important data into Thread.current[:status].
  # Method returns collected statuses.
  def process_parallel(&block)
    threads = []
    self.each_with_index do |value, index|
      threads << Thread.new do
        block[value, index]
      end
    end
    return threads.map { |t| t.join[:status] }
  end
end
