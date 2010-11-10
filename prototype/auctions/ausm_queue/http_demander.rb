#!/usr/bin/ruby

# Author: Yuri Gorshenin

require 'lib/ext/core_ext'
require 'lib/options'
require 'net/http'
require 'optparse'

def parse_options(argv)
  parser, file = OptionParser.new, nil
  options = { :bid => {} }

  parser.on("--config_file=CONFIG_FILE_YAML") { |config| file = config }
  parser.on("--server=SERVER") { |server| options[:server] = server }
  parser.on("--port=PORT") { |port| options[:port] = port.to_i }
  parser.on("--pay=PAY") { |pay| options[:bid][:pay] = pay.to_f }
  parser.on("--supplier_id=COMMA_LIST_OR_SINGLE_ID") { |list| options[:bid][:supplier_id] = list.split(',') }
  parser.on("--dimensions=COMMA_LIST") { |list| options[:bid][:dimensions] = list.split(',').map { |v| v.to_f } }
  parser.on("--demander_id=ID") { |id| options[:demander_id] = id }
  
  parser.parse(*argv)
  
  options = get_options_from_file(file).recursive_merge(options) if file

  unless options[:demander_id]
    STDERR.puts "demander_id must be specified!"
    exit -1
  end

  unless options[:bid][:supplier_id] and options[:bid][:pay] and options[:bid][:dimensions]
    STDERR.puts "bid options must be specified!"
    exit -1
  end
  
  options[:server] ||= 'localhost'
  options[:port] ||= 8080

  options
end

def send_bid(options)
  data = { :demander_id => options[:demander_id], :bid => options[:bid] }
  STDERR.puts data.inspect
  Net::HTTP.start(options[:server], options[:port]) do |http|
    response, body = http.post('/bid', YAML::dump(data))
    STDERR.puts body
  end
end

send_bid(parse_options(ARGV))
