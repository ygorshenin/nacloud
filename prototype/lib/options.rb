# Author: Yuri Gorshenin

require 'lib/ext/core_ext'
require 'yaml'

def get_options_from_file(file)
  options = YAML::load(File.open(file, 'r'))
  options.symbolize_keys_recursive!
end
