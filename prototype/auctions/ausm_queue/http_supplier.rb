#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'lib/options'

require 'auctions/base/supplier'
require 'net/http'
require 'optparse'
require 'yaml'

def parse_options(argv)
  parser, file = OptionParser.new, nil
  options = {}

  parser.on("--config_file=CONFIG_FILE_YAML") { |config| file = config }
  parser.on("--server=SERVER") { |server| options[:server] = server }
  parser.on("--port=PORT") { |port| options[:port] = port.to_i }
  parser.on("--supplier_id=ID") { |id| options[:supplier_id] = id }

  parser.parse(*argv)

  unless file
    STDERR.puts "config_file must be specified!"
    exit -1
  end

  options = get_options_from_file(file).merge(options)

  unless options[:dimensions] and options[:lower_costs] and options[:supplier_id]
    STDERR.puts "supplier parameters must be specified in config file!"
    exit -1
  end
    
  options[:server] ||= 'localhost'
  options[:port] ||= 8080
  options
end

def register_supplier(options)
  data = {
    :supplier_id => options[:supplier_id],
    :dimensions => options[:dimensions],
    :lower_costs => options[:lower_costs]
  }
  
  STDERR.puts data.inspect
  Net::HTTP.start(options[:server], options[:port]) do |http|
    response, body = http.post('/registration', YAML::dump(data))
    STDERR.puts body
  end
end

register_supplier(parse_options(ARGV))
