# Author: Yuri Gorshenin

require 'core_ext'
require 'logger'

# Class represents AUSMAuction
# User must create class with arrays of suppiers, demanders and options
# After creation, user must manually start auction by call run_auction
#
# Auctions continues until maximum number of iterations is exeeded, or
# after some iteration nothing is changed
#
# run_auction method returns tuple [ total iterations, total time, info ]

class AUSMAuction
  def initialize(suppiers, demanders, options)
    # Merging default options with user-specified

    @suppiers, @demanders = suppiers, demanders
    
    @options = {
      :max_iterations => 50,
      :one_decision_time => 20.seconds,
    }.merge(options)

    @logger = Logger.new(@options[:logfile] || STDERR) # Creating logger (to file, if specified, or to STDERR)

  end

  def run_auction
    @logger.info("started auction")
    
    total_time, total_iterations = 0, 0
    info = [] # Public-known queue with bids. Contains pairs <bid, status>, where status is :approved or :rejected
    model = AUSMModel.new(suppiers) # Model for AUSM auction

    @options[:max_iterations].times do
      total_iterations += 1
      
      @logger.info("auction iteration #{total_iterations}")
      changed = false

      demanders.each do |demander|
        bid = demander.get_bid(info)
        total_time += @options[:one_decision_time]
        
        @logger.info("user #{demander.user} bids #{bid}")
        
        if bid
          result = model.try_bid(demander, bid)
          if result
            info.push(total_iterations, demander.user, bid, result)
            changed = true
          end
        end
      end
      
      break unless changed
    end
    [ total_iterations, total_time, info ]
  end
end
