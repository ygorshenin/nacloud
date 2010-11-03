# Author: Yuri Gorshenin

require 'lib/core_ext'

# Algorithm solves Multidimensional Multiple Knapsack problem with GLPK.
# Algorithm generates two files for model and data, then calls glpsol utility.
# After that, script parses output file and retrieves allocation

# Model file looks like:

# set Items;
# set Dimensions;
# set Knapsacks;
# param Weights { i in Items, j in Dimensions };
# param Costs { i in Items };
# param Bounds { k in Knapsacks, j in Dimensions };
# var x { i in Items, k in Knapsacks } binary;
# maximize Profit: sum { i in Items, k in Knapsacks } x[i, k] * Costs[i];
# s.t. KnapsacksBound { k in Knapsacks, j in Dimensions }: sum { i in Items } x[i, k] * Weights[i, j] <= Bounds[k, j];
# s.t. OnlyOneKnapsack { i in Items } : sum { k in Knapsacks } x[i, k] <= 1;
# solve;
# printf: "Profit: %f\n", Profit > "knapsack.out";
# printf { i in Items, k in Knapsacks : x[i, k] = 1 }: "%s assigned to %s\n", i, k >> "knapsack.out";
# end;

# Data file looks like:

# set Items := Alpha Beta Gamma Delta;
# set Dimensions := Length Weight;
# set Knapsacks := Pocket Bag;
# param Weights :
#       	      Length	Weight :=
# Alpha	      4		6
# Beta	      6		4
# Gamma	      5		5
# Delta	      5		5;
# param Costs := Alpha 6, Beta 7, Gamma 12, Delta 13;
# param Bounds :
#       	     Length	Weight :=
# Pocket	     10		10
# Bag   	     10		10;
# end;

class GLPKMDMK
  def initialize(options={})
    @options = {
      :items => 'Items',
      :dimensions => 'Dimensions',
      :knapsacks => "Knapsacks",
      :weights => 'Weights',
      :costs => 'Costs',
      :bounds => 'Bounds',
      :preferences => 'Preferences',
      :result => 'Profit',
      :model_file => 'knapsack.mod',
      :data_file => 'knapsack.dat',
      :output_file => 'knapsack.out',
      :variable_name => 'x',
      :knapsacks_bounds => 'KnapsacksBounds',
      :only_one_knapsack => 'OnlyOneKnapsack',
      :preferences_bounds => 'PreferencesBounds',
      :glpsol => 'glpsol',
      :dump_model => true,
      :dump_data => true,
    }.merge(options)
  end

  def solve(values, requirements, bounds, preferences = nil)
    return [0, []] if values.empty? or bounds.empty?
    return [values.sum, [0] * values.size] if bounds.first.empty?
    
    dump_model(:preferences => preferences) if @options[:dump_model]
    dump_data(values, requirements, bounds, preferences) if @options[:dump_data]
    
    `#{@options[:glpsol]} --model #{@options[:model_file]} --data #{@options[:data_file]}`
    result = get_result(values.size)
    
    File.delete(@options[:output_file])
    File.delete(@options[:model_file]) if @options[:dump_model]
    File.delete(@options[:data_file]) if @options[:dump_data]
    result
  end

  private

  def dump_model(options = {})
    preferences = ''
    if options[:preferences]
      preferences = "param #{@options[:preferences]} { i in #{@options[:items]}, k in #{@options[:knapsacks]} } binary;"
      preferences += "\n\ns.t. #{@options[:preferences_bounds]} { i in #{@options[:items]}, k in #{@options[:knapsacks]} } : #{@options[:variable_name]}[i, k] <= #{@options[:preferences]}[i, k];"
    end
    model = <<END_OF_MODEL
set #{@options[:items]};

set #{@options[:dimensions]};

set #{@options[:knapsacks]};

param #{@options[:weights]} { i in #{@options[:items]}, j in #{@options[:dimensions]} };

param #{@options[:costs]} { i in #{@options[:items]} };

param #{@options[:bounds]} { k in #{@options[:knapsacks]}, j in #{@options[:dimensions]} };

var #{@options[:variable_name]} { i in #{@options[:items]}, k in #{@options[:knapsacks]} } binary;

maximize #{@options[:result]}: sum { i in #{@options[:items]}, k in #{@options[:knapsacks]} } #{@options[:variable_name]}[i, k] * #{@options[:costs]}[i];

s.t. #{@options[:knapsacks_bounds]} { k in #{@options[:knapsacks]}, j in #{@options[:dimensions]} }:

sum { i in #{@options[:items]} } #{@options[:variable_name]}[i, k] * #{@options[:weights]}[i, j] <= #{@options[:bounds]}[k, j];

s.t. #{@options[:only_one_knapsack]} { i in #{@options[:items]} } : sum { k in #{@options[:knapsacks]} } #{@options[:variable_name]}[i, k] <= 1;

#{preferences}

solve;

printf: "#{@options[:result]}:%f\\n", #{@options[:result]} > "#{@options[:output_file]}";

printf { i in #{@options[:items]}, k in #{@options[:knapsacks]} : x[i, k] = 1 }: "%d->%d\\n", i, k >> "#{@options[:output_file]}";

end;

END_OF_MODEL
    File.open(@options[:model_file], 'w') do |file|
      file.puts model
    end
  end

  def dump_data(values, requirements, bounds, pref = nil)
    items, knapsacks, dimensions = [values, bounds, bounds.first].map { |v| (0 ... v.size).to_a }
    weights = dimensions.join(' ') + ":=\n" +
      items.zip(requirements).map { |v| v.join(' ') }.join("\n")

    preferences = ''
    if pref
      preferences = "param #{@options[:preferences]}:\n" +
        knapsacks.join(' ') + ":=\n" +items.zip(pref).map { |v| v.join(' ') }.join("\n") + ';'
    end
    
    data = <<END_OF_DATA
set #{@options[:items]}:=#{items.join(' ')};
set #{@options[:dimensions]}:=#{dimensions.join(' ')};
set #{@options[:knapsacks]}:=#{knapsacks.join(' ')};
param #{@options[:weights]}:\n#{weights};
param #{@options[:costs]}:=#{items.zip(values).map { |v| v.join(' ') }.join(',')};
param #{@options[:bounds]}:
#{dimensions.join(' ')}:=
#{knapsacks.zip(bounds).map { |v| v.join(' ') }.join("\n")};
#{preferences}
end;
END_OF_DATA
    File.open(@options[:data_file], 'w') do |file|
      file.puts data
    end
  end

  def get_result(n)
    result_regex = /#{@options[:result]}:(.+)/
    assignment_regex = /(.+)->(.+)/
    result, assignment = 0, Array.new(n)
    File.open(@options[:output_file], 'r') do |file|
      file.each do |line|
        line.strip!
        if line =~ assignment_regex
          assignment[$1.to_i] = $2.to_i
        elsif line =~ result_regex
          result = $1.to_f
        end
      end
    end
    return [ result, assignment ]
  end
end
