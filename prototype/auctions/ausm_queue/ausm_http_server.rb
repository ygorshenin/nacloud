#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'lib/ext/core_ext'
require 'lib/options'
require 'logger'
require 'optparse'
require 'socket'
require 'thread'

# Simple HTTP server
# Redirects post and get requests to model
module SimpleHTTPServer
  def run_http_server(host, port, logfile = nil)
    @server = TCPServer.new(host, port)
    @logger ||= Logger.new(logfile || STDERR)
    loop do
      Thread.new(@server.accept) do |session|
        @logger.info("new session: #{session.peeraddr.inspect}")
        headers = read_headers(session)
        request_type = get_request_type(headers)
        resource = get_resource(headers)
        @logger.info("headers: #{headers}")
        @logger.info("request-type: #{request_type}")
        @logger.info("resource: #{resource}")

        session.print "HTTP/1.1 200 OK\r\nContent-type: text/html\r\n\r\n"
        session.print "Hello, Client!\r\n"

        session.close
      end
    end
  end

  private

  def get_request_type(headers)
    case headers
    when /^GET/i : return :get
    when /^POST/i : return :post
    end
  end

  def get_resource(headers)
    headers.lines.to_a[0].gsub(/^\w+/, '').gsub(/HTTP.*$/i, '')
  end
  
  def read_headers(session)
    header = ''
    while not (line = session.gets).strip.empty? do
        header += line
    end
    header
  end
  
  def get_content_length(headers)
    headers.match(/Content-Length:\s*(\d+)/i)[1].to_i
  end

  def read_content(headers, session)
    session.read(get_content_length(headers))
  end
end

class AUSMHTTPServerQueue
  include SimpleHTTPServer
  
  def initialize(options = {})
    @options = {
      :registration_period => 10.minutes,
      :deadline_period => 4.minutes,
      :port => 8080,
    }.merge(options)
    @logger = Logger.new(@options[:logfile] || STDERR)
    @suppliers = []
  end

  def run_auction
    run_http_server('localhost', @options[:port])
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
