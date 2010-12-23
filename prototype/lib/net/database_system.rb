# Author: Yuri Gorshenin

require 'rubygems'

require 'cassandra'
require 'drb'
require 'yaml'

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

  def start(uri)
    DRb.start_service uri, self
  end

  def stop
    DRb.stop_service
  end

  def exists_job?(options)
    jobs = @client.get(@options[:cf_jobs], options[:user])
    return jobs.has_key?(options[:name])
  end

  # inserts job key into cf_jobs[user][name]
  def insert_job(job)
    key = job[:user] + ':' + job[:name]
    # bad solution - use job description as key,
    # but this is prototype. Hope, in next versions it'll changed.
    @client.insert(@options[:cf_jobs], job[:user], { job[:name] => job.to_yaml })
  end

  def get_job_description(job)
    content = @client.get(@options[:cf_jobs], job[:user])[job[:name]]
    YAML::load(content)
  end

  def get_jobs_list(options)
    @client.get(@options[:cf_jobs], options[:user]).keys
  end

  def delete_job(options)
    key = get_key(options)
    @client.remove(@options[:cf_jobs], options[:user], options[:name])
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

  # gets job key from cf_jobs[user][name]
  def get_key(job)
    @client.get(@options[:cf_jobs], job[:user], job[:name])
  end
end
