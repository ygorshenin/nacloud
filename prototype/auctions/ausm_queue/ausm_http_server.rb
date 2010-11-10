#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'auctions/base/supplier'
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
    
    @state = :new
    
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
      @mutex.synchronize { @state = :auction }
      @logger.info "auction begins"
      sleep 24.hours
    end

    timing.join
  end
  
  private
  
  def register_supplier(supplier, result)
    @logger.info("registering supplier <#{supplier.to_s}>")
    @mutex.synchronize do
      status, reason, response = 200, 'OK', 'Accepted'
      if @state == :registration
        index = @id_to_supplier_index[supplier.get_id] || @suppliers.size
        @id_to_supplier_index[supplier.get_id] = index
        @suppliers[index] = supplier
        @logger.info "registration succeeded"
      else
        status, reason, response = 503, 'Service Unavailable', 'Registration is closed'
        @logger.info "registration failed"
      end
      result.replace({
                       :status => status,
                       :reason => reason,
                       :response => response,
                     })
    end
  end

  def get_status(result)
    response = <<END_OF_RESPONSE
<tt>
<b>state:</b> #@state<br>
<b>registration period (sec):</b> #{@options[:registration_period]}<br>
<b>deadline period (sec):</b> #{@options[:deadline_period]}<br>
<b>current time:</b> #{Time.now}<br>
<b>registration start:</b> #@registration_start<br>
<b>registration end:</b> #@registration_end<br>
<b>auction start:</b> #@auction_start<br>
<b>suppliers:</b><br>
#{@suppliers.collect { |supplier| supplier.to_s + "<br>" }}
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
      content = YAML.load(read_content(headers, session))
      supplier = Supplier.new(content[:id], content[:dimensions], content[:lower_costs])
      register_supplier(supplier, result)
    when '/bid'
    end
  end

  def http_get(headers, session, result)
    resource = get_resource(headers).downcase
    case resource
    when '/info'
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
