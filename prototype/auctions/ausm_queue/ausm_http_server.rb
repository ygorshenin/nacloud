#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'auctions/ausm_queue/auction_model'
require 'auctions/base/demander'
require 'auctions/base/html_allocation'
require 'auctions/base/supplier'
require 'lib/algo/glpk_mdknapsack'
require 'lib/ext/core_ext'
require 'lib/net/http_server'
require 'lib/options'
require 'optparse'
require 'thread'

class AUSMHTTPServerQueue
  include SimpleHTTPServer
  
  def initialize(options = {})
    @options = {
      :registration_period => 1.minutes,
      :deadline_period => 4.minutes,
      :port => 8080,
    }.merge(options)
    @logger = Logger.new(@options[:logfile] || STDERR)
    
    @state, @info = :new, []
    
    @suppliers, @id_to_supplier_index = [], {}

    @mutex = Mutex.new # Global model mutex
  end

  def run_auction
    server = Thread.new { run_http_server('localhost', @options[:port]) }

    @registration_start = Time.now
    @auction_start = @registration_end = Time.now + @options[:registration_period]
    
    timing = Thread.new do
      @logger.info "registration begins"
      
      @mutex.synchronize { @state = :registration }
      sleep @options[:registration_period]
      
      @logger.info "registration ends"
      
      @mutex.synchronize do
        @state = :auction
        @model = AUSMModelQueue.new(@suppliers, GLPKMDKnapsack.new)
        @last_bid_time = Time.now
      end
      @logger.info "auction begins"
      
      sleep 24.hours
    end

    timing.join
  end
  
  private
  
  def register_supplier(supplier, result)
    @logger.info("registering supplier <#{supplier.to_s}>")
    @mutex.synchronize do
      status, reason, response = 200, 'OK', 'accepted'
      if @state == :registration
        index = @id_to_supplier_index[supplier.get_id] || @suppliers.size
        @id_to_supplier_index[supplier.get_id] = index
        @suppliers[index] = supplier
        @logger.info "registration succeeded"
      else
        status, reason, response = 503, 'Service Unavailable', 'registration is closed'
        @logger.info "registration failed"
      end
      result.replace({
                       :status => status,
                       :reason => reason,
                       :response => response,
                     })
    end
  end

  def apply_bid(demander, bid, result)
    @logger.info("applying bid #{bid.inspect} from #{demander}")
    @mutex.synchronize do
      status, reason, response = 200, 'OK', ''
      if @state == :auction
        response = @model.try_bid(demander, bid)
        @last_bid_time = Time.now if response == :accepted
        @logger.info("status: #{response}")

        @info.push({
                     :allocation => @model.allocation.dup,
                     :demander => demander,
                     :bid => bid,
                     :time => Time.now,
                     :status => response,
                   })
      else
        status, reason, response = 503, 'Service Unavailable', 'Auction is closed'
        @logger.info "bid failed"
      end
      result.replace({
                       :status => status,
                       :reason => reason,
                       :response => response,
                     })
    end
  end

  def get_info
    parts = []
    @mutex.synchronize do
      parts = @info.reverse.map do |item|
<<END_OF_PART
<b>bid:</b> #{HTMLAllocation::stringify_bid(item[:demander], item[:bid])}<br>
<b>time:</b> #{item[:time]}<br>
<b>status:</b> #{item[:status]}<br>
<b>allocation:</b><br>
#{HTMLAllocation::represent(item[:allocation])}
END_OF_PART
      end
    end
    parts.join('<hr>')
  end

  def get_status(result)
    response = <<END_OF_RESPONSE
<tt>
<b>state:</b> #@state<br>
<b>registration period (sec):</b> #{@options[:registration_period]}<br>
<b>deadline period (sec):</b> #{@options[:deadline_period]}<br>
<b>server time:</b> #{Time.now}<br>
<b>registration start:</b> #@registration_start<br>
<b>registration end:</b> #@registration_end<br>
<b>auction start:</b> #@auction_start<br>
<b>last bid time:</b> #@last_bid_time<br>
<b>suppliers:</b><br>
#{@suppliers.collect { |supplier| supplier.to_s + "<br>" }}
<p>
<b>info:</b><br>
#{get_info}
</p>
END_OF_RESPONSE
    result.replace({
                     :status => 200,
                     :reason => 'OK',
                     :response => response,
                   })
  end
  
  def http_post(headers, session, result)
    resource = get_resource(headers).downcase
    case resource
    when '/registration'
      content = YAML::load(read_content(headers, session))
      supplier = Supplier.new(content[:supplier_id], content[:dimensions], content[:lower_costs])
      register_supplier(supplier, result)
    when '/bid'
      content = YAML::load(read_content(headers, session))
      demander = Demander.new(content[:demander_id])
      apply_bid(demander, content[:bid], result)
    end
  end

  def http_get(headers, session, result)
    resource = get_resource(headers).downcase
    case resource
    when '/'
      get_status(result)
    end
  end
end

def get_options(argv)
  parser, file = OptionParser.new, nil
  options = {}
  
  parser.on("--config_file=CONFIG_FILE_YAML")  { |config| file = config }
  parser.on("--registration_period=VAL") { |val| options[:registration_period] = val.to_i }
  parser.on("--deadline_period=VAL") { |val| options[:deadline_period] = val.to_i }

  parser.parse(*argv)

  options = get_options_from_file(file).merge(options) if file
  options
end

server = AUSMHTTPServerQueue.new(get_options(ARGV))
server.run_auction
