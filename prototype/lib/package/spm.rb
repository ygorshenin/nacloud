# Author: Yuri Gorshenin

require 'fileutils'
require 'lib/ext/core_ext'

# Simple packet manager class.
# Can only build packages and install them.
# Packages now are .tar.gz files.
# Config is a Hash, contains job specification and used packages.
# For instance:
# job:
#  binary: ~/coding/hungarian
#  args:
#    input_file: data/input.dat
#    output_file: data/output.dat
#    config_file: other/config.yaml
#
#  packages: [ input_data, configuration ]
# 
# input_data:
#   files: [ ~/downloads/input.txt ]
#   dest: data
#
# configuration:
#   file: ~/my/config.yaml
#   dest: other
class SPM
  # Build spm file simply by copying binaries, specified in config file, tar-ing and gzip-ing them.
  def self.build(config, name, options = {})
    check_config(config)
    
    tmp_dir = get_tmp_dir

    begin
      FileUtils.mkdir(tmp_dir, options)
      FileUtils.cp(config[:job][:binary], tmp_dir, options) if config[:job][:binary]

      config[:job][:packages].each do |package|
        target = File.join(tmp_dir, config[package][:dest])
        FileUtils.mkdir_p(target, options)
        config[package][:files].each { |file| FileUtils.cp(file, target, options) }
      end
      
      archive = File.basename(name) + '.tar.gz'
      result = `cd #{tmp_dir}; tar -czf #{archive} * --remove-files`
      raise RuntimeError.new(result) unless $?.success?
      FileUtils.mv(File.join(tmp_dir, archive), File.expand_path(name), options)
    ensure
      FileUtils.rm_rf(tmp_dir)
    end
  end

  # src is the path to package file
  # dst is the directory, where to put compressed files
  def self.install(src, dst, options)
    archive = File.basename(src) + '.tar.gz'
    FileUtils.cp(File.expand_path(src), File.expand_path(File.join(dst, archive)), options)
    result = `cd #{dst}; tar -xzf #{archive}; rm #{archive}`
    raise RuntimeError(result) unless $?.success?
  end

  private

  def self.get_tmp_dir
    "tmp.#{Time.now.to_i}.#{Process.pid}"
  end

  # Checks config[package] section.
  # Convers to array (creates empty, if need) :files subsection, deletes :file subsection.
  # Creates (if need) :dest subsection with default value '.'.
  # Raises argument error, if fails.
  def self.check_package(config, package)
    raise ArgumentError.new("package #{package} is specified but not described") unless config[package]
    config[package][:files] = Array(config[package][:files] || [])
    config[package][:files].push(config[package].delete(:file)) if config[package][:file]
    config[package][:dest] = '.' unless config[package][:dest]

    config[package][:files].map! { |file| File.expand_path(file) }
  end

  # Checks config[:job][:packages] section.
  # Converts to array (creates empty, if need), checks all needed packages.
  # Raises argument error, if fails.
  def self.check_packages(config)
    config[:job][:packages] = Array(config[:job][:packages] || [])
    config[:job][:packages].map! { |package| package.to_sym }.each do |package|
      check_package(config, package)
    end
  end

  # Checks configuration file.
  # Also makes small changes (transforms package section to array,
  # replaces file section to files in package specification).
  # Raises argument error, if fails.
  def self.check_config(config)
    raise ArgumentError.new("job section must be specified") unless config[:job]
    config[:job][:binary] = File.expand_path(config[:job][:binary]) if config[:job][:binary]
    check_packages(config)
  end
end
