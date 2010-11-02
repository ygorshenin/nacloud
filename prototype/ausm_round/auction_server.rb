# Author: Yuri Gorshenin

require 'auction_model'
require 'lib/core_ext'
require 'logger'

# Class represents AUSMAuction with Rounds
# User must create class with arrays of suppiers, demanders and options
# After creation, user must manually start auction by call run_auction
#
# Auctions continues until maximum number of iterations is exeeded
#
# run_auction method returns hash { :allocation, :total iterations, :auction_info }
# where allocation is array [ { :demander, :bid } ]

class AUSMAuctionRound
  def initialize(suppiers, demanders, options={})
    # Merging default options with user-specified    
    @suppiers, @demanders = suppiers, demanders
    @options = {
      :max_iterations => 50,
    }.merge(options)

    @logger = Logger.new(@options[:logfile] || STDERR) # Creating logger (to file, if specified, or to STDERR)
  end

  def run_auction
    @logger.info("auction started")

    info = []
    model = AUSMModelRound.new(@suppiers) # Model for AUSM auction

    (1 .. @options[:max_iterations]).each do |iteration|
      process_round(model, iteration, info)
    end

    @logger.info("auction stops after #{@options[:max_iterations]} iterations")

    { :allocation => model.allocation,
      :total_iterations => @options[:max_iterations],
      :auction_info => info,
    }
  end

  private

  def process_round(model, iteration, info)
    @logger.info("iteration #{iteration}")
    bids = []
    @demanders.each do |demander|
      bid = demander.get_bid(@suppliers, info)
      @logger.info("#{demander.get_id} proposed bid #{bid.inspect}")
      bids.push([demander, bid])
    end
    model.allocate_bids(bids)
    info.push({ :allocation => model.allocation.dup,
                :iteration => iteration,
              })
  end
end
