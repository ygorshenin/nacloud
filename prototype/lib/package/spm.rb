# Author: Yuri Gorshenin

require 'fileutils'
require 'lib/ext/core_ext'

# Simple packet manager class.
# Can only build packages and install them.
# Packages now are .tgz files.
# Config is a Hash, contains package specification
# For instance:
#
# name: mypkg
# data:
#   - source: absolute source pattern
#     target: local directory
#

class SPM
  # Build spm file simply by copying binaries, specified in config file, tar-ing and gzip-ing them.
  def self.build(config)
    config[:data] ||= []
    check_config(config)
    tmp_dir = get_tmp_dir # Obtain temprorary path
    begin
      FileUtils.mkdir(tmp_dir) # Creates temprorary directory
      config[:data].map { |h| h.symbolize_keys_recursive! } # Makes all keys in config[:data] hashes symbolic
      config[:data].each do |h|
        target = File.join(tmp_dir, h[:target])
        FileUtils.mkdir_p(target) # Creates target directory
        FileUtils.cp_r(h[:source], target) if h.has_key? :source # Copies all necessary files
      end
      archive = config[:name] + '.tgz'
      result = `cd #{tmp_dir}; tar -czf #{File.join("..", archive)} *; rm -rf *` # tar-gzips archive
      raise RuntimeError.new(result) unless $?.success?
      FileUtils.mv(File.join(tmp_dir, "..", archive), File.expand_path(config[:name]))
    ensure
      FileUtils.rm_rf(tmp_dir)
    end
  end

  # src is the path to package file
  # dst is the directory, where to put compressed files
  def self.install(src, dst)
    archive = File.basename(src) + '.tgz'
    FileUtils.cp(File.expand_path(src), File.expand_path(File.join(dst, archive)))
    result = `cd #{dst}; tar -xzf #{archive}; rm #{archive}`
    raise RuntimeError(result) unless $?.success?
  end

  private

  def self.get_tmp_dir
    "tmp.#{Time.now.to_i}.#{Process.pid}"
  end

  # Checks configuration file.
  def self.check_config(config)
    raise ArgumentError.new("name section must be specified") unless config[:name]
  end
end
