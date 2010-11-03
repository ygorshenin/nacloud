# Author: Yuri Gorshenin

require 'ausm_queue/auction_model'
require 'lib/core_ext'
require 'logger'

# Class represents AUSMAuction
# User must create class with arrays of suppiers, demanders and options
# After creation, user must manually start auction by call run_auction
#
# Auctions continues until maximum number of iterations is exeeded, or
# after some iteration nothing is changed
#
# run_auction method returns hash { :allocation, :total iterations, :auction_info }
# where allocation is array [ { :demander, :bid } ]

class AUSMAuction
  def initialize(suppliers, demanders, options={})
    # Merging default options with user-specified

    @suppliers, @demanders = suppliers, demanders
    
    @options = {
      :max_iterations => 50,
    }.merge(options)

    @logger = Logger.new(@options[:logfile] || STDERR) # Creating logger (to file, if specified, or to STDERR)
  end

  def run_auction
    @logger.info("auction started")
    
    total_iterations, info = 0, []
    model = AUSMModel.new(@suppliers) # Model for AUSM auction

    @options[:max_iterations].times do
      total_iterations += 1
      process_round(model, total_iterations, info)
    end
    
    @logger.info("auction stops after #{total_iterations} iterations")

    { :allocation => model.allocation,
      :total_iterations => total_iterations,
      :auction_info => info,
    }
  end

  # returns false if nothing changed in this round
  def process_round(model, iteration, info)
    @logger.info("iteration #{iteration}")
    
    @demanders.each do |demander|
      if not model.in_allocation?(demander)
        bid = demander.get_bid(@suppliers, info)
        status = model.try_bid(demander, bid)

        @logger.info("#{demander.get_id} proposed bid #{bid.inspect}")
        @logger.info("status: #{status}")
        
        info.push({ :allocation => model.allocation.dup,
                    :iteration => iteration,
                    :demander => demander,
                    :bid => bid,
                    :status => status,
                  })
      end
    end
  end
end
