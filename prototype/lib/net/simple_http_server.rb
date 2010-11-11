# Author: Yuri Gorshenin

require 'gserver'

# Simple HTTP Server.
# Now can serve only GET and POST requests.
# Before usage, client must specify all necessary callbacks
# by calling "on" function.
# For GET requests user must specify lambda { } callback.
# For POST requests user must specify lambda { |content| } callback.
# Result must be { :status => status_code, :reason => reason_msg, :response => response_msg }.
class SimpleHTTPServer < GServer
  HTTP_VERSION = 'HTTP/1.1'
  DEFAULT_RESPONSE = { :status => 404, :reason => 'Not Found', :response => 'Required page not found' }
  
  def initialize(port = 8080, *args)
    super(port, *args)
    @table = {}
  end

  def serve(io)
    headers = read_headers(io)
    method, resource = get_method_type(headers), get_resource(headers)

    response = DEFAULT_RESPONSE

    if @table[method] and @table[method][resource]
      if method == :post
        content = read_content(headers, io)
        response = @table[method][resource][content]
      elsif method == :get
        response = @table[method][resource][]
      end
    end

    io.print "#{HTTP_VERSION} #{response[:status]} #{response[:reason]}\r\n"
    io.print "Content-Type: text/html\r\n\r\n"
    io.print "#{response[:response]}\r\n"
  end

  def on(method, resource, &block)
    @table[method] ||= {}
    @table[method][resource] ||= []
    @table[method][resource] = block
  end

  private
  
  def read_headers(io)
    header = ''
    while not (line = io.gets).strip.empty?
      header += line
    end
    header
  end

  def get_content_length(headers)
    result = headers =~ /Content-Length:\s*(\d+)/i ? $1.to_i : 0
    result = 0 if result < 0
    result
  end

  def read_content(headers, io)
    io.read(get_content_length(headers))
  end  

  def get_resource(headers)
    headers.lines.to_a.first.split[1]
  end

  def get_method_type(headers)
    headers.lines.to_a.first.split.first.downcase.to_sym
  end
end
