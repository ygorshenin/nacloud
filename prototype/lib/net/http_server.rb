# Author: Yuri Gorshenin

require 'logger'
require 'socket'
require 'thread'

# Simple HTTP server
# Redirects post and get requests to containing class
# Containing class must specify http_get(headers, session, result) and http_post(headers, session, result) functions.
# Result must be { :status => status_code, :reason => reason_msg, :response => response_msg }.
module SimpleHTTPServer
  HTTP_VERSION = "HTTP/1.1"
  
  def run_http_server(host, port, logfile = nil)
    @server = TCPServer.new(host, port)
    @logger ||= Logger.new(logfile || STDERR)
    loop do
      thread = Thread.new(@server.accept) do |session|
        @logger.info("new session: #{session.peeraddr.inspect}")
        headers = read_headers(session)
        request_type = get_request_type(headers)
        @logger.info("headers: #{headers}")
        @logger.info("request-type: #{request_type}")
        result = { :status => 500, :reason => 'Internal Server Error', :response => "Behavior doesn't supported" }
        send(request_type, headers, session, result)
        
        session.print "#{HTTP_VERSION} #{result[:status]} #{result[:reason]}\r\n"
        session.print "Content-Type: text/html\r\n\r\n"
        session.print "#{result[:response]}\r\n"
        
        session.close
      end
    end
  end

  private

  def get_request_type(headers)
    case headers
    when /^GET/i : return :http_get
    when /^POST/i : return :http_post
    end
  end

  def get_resource(headers)
    headers.lines.to_a[0].strip.gsub(/^\w+\s*/, '').gsub(/\s*HTTP.*$/i, '')
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
