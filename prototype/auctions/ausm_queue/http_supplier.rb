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

  parser.on("--config_file=FILE", String) { |config| file = config }
  parser.on("--server=SERVER", String) { |server| options[:server] = server }
  parser.on("--port=PORT", Integer) { |port| options[:port] = port }
  parser.on("--supplier_id=ID", String) { |id| options[:supplier_id] = id }
  parser.on("--dimensions=LIST", Array) { |list| options[:dimensions] = list.map { |v| v.to_f } }
  parser.on("--lower_costs=LIST", Array) { |list| options[:lower_costs] = list.map { |v| v.to_f } }

  parser.parse(*argv)

  options = get_options_from_file(file).merge(options) if file

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
