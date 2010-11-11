#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'auctions/ausm_queue/auction_model'
require 'auctions/base/demander'
require 'auctions/base/html_allocation'
require 'auctions/base/supplier'
require 'lib/algo/glpk_mdknapsack'
require 'lib/ext/core_ext'
require 'lib/net/simple_http_server'
require 'lib/options'
require 'logger'
require 'optparse'
require 'thread'

class AUSMHTTPServerQueue
  def initialize(options = {})
    @options = {
      :registration_period => 1.minutes,
      :deadline_period => 1.minutes,
      :idle_period => 24.hours,
      :heart_beat => 1.second,
      :port => 8080,
    }.merge(options)
    
    @logger = Logger.new(@options[:logfile] || STDERR)
    
    @server = SimpleHTTPServer.new(@options[:port])
    @server.on(:get, '/') { http_get_status }
    @server.on(:post, '/registration') { |data| http_register_supplier(data) }
    @server.on(:post, '/bid') { |data| http_apply_bid(data) }
    
    @state, @info = :new, [] # Current auction state and auction information
    @suppliers, @id_to_supplier_index = [], {} # Array of registered suppliers and Hash { :supplier_id => index in array }
    @mutex = Mutex.new # Global model mutex
  end

  def run_auction
    @server.start
    timing
    
    sleep @options[:idle_period] # Sleeps after auction's end
    @server.shutdown # Shutdown server
  end
  
  private

  # Schedule to all auction process
  def timing
    @registration_start = Time.now
    @auction_start = @registration_end = Time.now + @options[:registration_period]
    
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

    ok = true
    while ok do
      @mutex.synchronize do
        if Time.now >= @last_bid_time + @options[:deadline_period]
          @state = :end
          @logger.info "auction ends"
          ok = false
        end
      end
      sleep @options[:heart_beat] if ok
    end
  end
  
  def http_register_supplier(data)
    content = YAML::load(data)
    supplier = Supplier.new(content[:supplier_id], content[:dimensions], content[:lower_costs])
    
    @logger.info "registering supplier <#{supplier.to_s}>"
    
    @mutex.synchronize do
      if @state == :registration
        index = @id_to_supplier_index[supplier.get_id] || @suppliers.size
        @id_to_supplier_index[supplier.get_id] = index
        @suppliers[index] = supplier
        
        @logger.info "registration succeeded"
        
        return { :status => 200, :reason => 'OK', :response => 'accepted' }
      else
        @logger.info "registration failed"

        return { :status => 503, :reason => 'Service Unavailable', :response => 'registration is closed' }
      end
    end
  end

  def http_apply_bid(data)
    content = YAML::load(data)
    demander, bid = Demander.new(content[:demander_id]), content[:bid]
    
    @logger.info "applying bid #{bid.inspect} from #{demander}"
    
    @mutex.synchronize do
      if @state == :auction
        response = @model.try_bid(demander, bid)
        @last_bid_time = Time.now if response == :accepted
        
        @logger.info "status: #{response}"

        @info.push({
                     :allocation => @model.allocation.dup,
                     :demander => demander,
                     :bid => bid,
                     :time => Time.now,
                     :status => response
                   })
        
        return { :status => 200, :reason => 'OK', :response => response.to_s }
      else
        @logger.info "bid failed"
        
        return { :status => 503, :reason => 'Service Unavailable', :response => 'auction is closed' }
      end
    end
  end

  # Gets auction info as list of tables and data
  def get_info
    parts = []
    @mutex.synchronize do
      parts = @info.reverse.map do |item|
        status_color = item[:status] == :accepted ? 'green' : 'red'
<<END_OF_PART
<b>bid:</b> #{HTMLAllocation::stringify_bid(item[:demander], item[:bid])}<br>
<b>time:</b> #{item[:time]}<br>
<b>status: <span style="color:#{status_color}">#{item[:status]}</span></b><br>
<b>allocation:</b><br>
#{HTMLAllocation::represent(item[:allocation])}
END_OF_PART
      end
    end
    parts.join('<hr>')
  end

  # Gets all important server variables and auction info as HTML document
  def http_get_status
    response = <<END_OF_RESPONSE
<tt>
<p><b>state: #@state</b><br></p>

<p>#{@options.collect { |k, v| "<b>#{k}</b>: #{v}<br>" }.sort.join("\n")}</p>

<b>registration start:</b> #@registration_start<br>
<b>registration end:</b> #@registration_end<br>
<b>auction start:</b> #@auction_start<br>
<b>last bid time:</b> #@last_bid_time<br>
<b>server time:</b> #{Time.now}<br>
<b>suppliers:</b><br>
#{@suppliers.collect { |supplier| supplier.to_s + "<br>" }}

<p><b>info:</b><br>#{get_info}</p>
END_OF_RESPONSE
    return { :status => 200, :reason => 'OK', :response => response }
  end
end

def get_options(argv)
  parser, file = OptionParser.new, nil
  options = {}
  
  parser.on("--config_file=CONFIG_FILE_YAML")  { |config| file = config }
  parser.on("--registration_period=VAL") { |val| options[:registration_period] = val.to_i }
  parser.on("--deadline_period=VAL") { |val| options[:deadline_period] = val.to_i }
  parser.on("--idle_period=VAL") { |val| options[:idle_period] = val.to_i }
  parser.on("--heart_beat=VAL") { |val| options[:heart_beat] = val.to_i }

  parser.parse(*argv)

  options = get_options_from_file(file).merge(options) if file
  options
end

server = AUSMHTTPServerQueue.new(get_options(ARGV))
server.run_auction
