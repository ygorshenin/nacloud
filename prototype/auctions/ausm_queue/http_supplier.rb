#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'lib/options'

require 'auctions/base/supplier'
require 'net/http'
require 'optparse'
require 'yaml'

def parse_options(argv)
  parser, file = OptionParser.new, nil
  options = {
    :server => 'localhost',
    :port => 80,
  }
  

  parser.on("--config_file=CONFIG_FILE_YAML") { |config| file = config }
  parser.on("--server=SERVER") { |server| options[:server] = server }
  parser.on("--port=PORT") { |port| options[:port] = port.to_i }

  parser.parse(*argv)

  if not file
    STDERR.puts "config_file must be specified!"
    exit -1
  end
  
  options = get_options_from_file(file).merge(options) if file
  options
end

def register_supplier(options)
  data = { :id => options[:id], :dimensions => options[:dimensions], :lower_costs => options[:lower_costs] }
  STDERR.puts data.inspect
  Net::HTTP.start(options[:server], options[:port]) do |http|
    http.post('/registration', YAML::dump(data))
  end
end

register_supplier(parse_options(ARGV))
