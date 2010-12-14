require 'drb'
require 'rubygems'
require 'cassandra'

# DatabaseSystem allows us to put/get binaries, commands and packages into Cassandra's database

class DatabaseSystem
  include DRbUndumped
  
  attr_accessor :host, :port, :options
  
  def initialize(options = {})
    @options = {
      :host => '127.0.0.1',
      :port => '9160',
      :user => '',
      :password => '',
      :keyspace => 'Storage',

      :cf_jobs => :Jobs,
      :cf_binaries => :Binaries,
      :cf_packages => :Packages,
      :col_binary => 'binary',
    }.merge(options)
    @client = Cassandra.new(@options[:keyspace], @options[:host] + ':' + @options[:port].to_s)
  end

  def insert_job(options)
    @client.insert(@options[:cf_jobs], options[:user], { options[:job] => options[:user] + ':' + options[:job] })
  end

  def get_jobs_list(options)
    @client.get(@options[:cf_jobs], options[:user]).keys
  end

  def delete_job(options)
    key = get_key(options)
    @client.remove(@options[:cf_jobs], options[:user], options[:job])
    @client.remove(@options[:cf_binaries], key)
    @client.remove(@options[:cf_packages], key)
  end

  def insert_binary(binary, options)
    @client.insert(@options[:cf_binaries], get_key(options), { @options[:col_binary] => binary })
  end

  def insert_package(package, options)
    @client.insert(@options[:cf_packages], get_key(options), { options[:package_name] => package })
  end

  def get_binary(options)
    @client.get(@options[:cf_binaries], get_key(options), @options[:col_binary])
  end

  def get_package(options)
    @client.get(@options[:cf_packages], get_key(options), options[:package_name])
  end
  
  private

  def get_key(options)
    @client.get(@options[:cf_jobs], options[:user], options[:job])
  end
end
