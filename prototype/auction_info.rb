# Author: Yuri Gorshenin

# Class represents auction information, thats available for auctioneers
class AuctionInfo
  attr_reader :info
  
  def initialize
    @info = []
  end

  def push(iteration, user, bid, status)
    @info.push([iteration, user, bid, status])
  end
end
