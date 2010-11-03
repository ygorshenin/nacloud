# Author: Yuri Gorshenin

class GLPKMDKnapsack
  def initialize(options={})
    @options = {
      :items => 'Items',
      :dimensions => 'Dimensions',
      :weights => 'Weights',
      :costs => 'Costs',
      :bounds => 'Bounds',
      :result => 'Profit',
      :model_file => 'knapsack.mod',
      :data_file => 'knapsack.dat',
      :output_file => 'knapsack.out',
      :variable_name => 'x',
      :knapsack_subject => 'KnapsackSubject',
      :glpsol => 'glpsol',
      :dump_model => true,
      :dump_data => true,
    }.merge(options)
  end

  def solve(values, requirements, bounds)
    dump_model if @options[:dump_model]
    dump_data(values, requirements, bounds) if @options[:dump_data]
    `#{@options[:glpsol]} --model #{@options[:model_file]} --data #{@options[:data_file]}`
    result = get_result
    File.delete(@options[:output_file])
    File.delete(@options[:model_file]) if @options[:dump_model]
    File.delete(@options[:data_file]) if @options[:dump_data]
    result
  end

  private
  
  def dump_model
    model = <<END_OF_MODEL
set #{@options[:items]};
set #{@options[:dimensions]};
param #{@options[:weights]} { i in #{@options[:items]}, j in #{@options[:dimensions]} };
param #{@options[:costs]} { i in #{@options[:items]}};
param #{@options[:bounds]} { j in #{@options[:dimensions]} };
var x { i in #{@options[:items]} } binary;
maximize #{@options[:result]} : sum { i in #{@options[:items]} } x[i] * #{@options[:costs]}[i];
s.t. #{@options[:knapsack_subject]} { j in #{@options[:dimensions]} }:
     sum { i in #{@options[:items]} } x[i] * #{@options[:weights]}[i, j] <= #{@options[:bounds]}[j];
solve;
printf "#{@options[:result]}:%f\\n", #{@options[:result]} > "#{@options[:output_file]}";
printf { i in #{@options[:items]} }: "#{@options[:variable_name]}[%s]:%d\\n", i, #{@options[:variable_name]}[i] >> "#{@options[:output_file]}";
end;
END_OF_MODEL
    File.open(@options[:model_file], 'w') do |file|
      file.puts model
    end
  end

  def dump_data(values, requirements, bounds)
    items, dimensions = [values, bounds].map { |v| (0 ... v.size).to_a }
    weights = dimensions.join(' ') + ":=\n" +
      items.zip(requirements).map { |v| v.join(' ') }.join("\n")

    data = <<END_OF_DATA
set #{@options[:items]}:=#{items.join(' ')};
set #{@options[:dimensions]}:=#{dimensions.join(' ')};
param #{@options[:weights]}:\n#{weights};
param #{@options[:costs]}:=#{items.zip(values).map { |v| v.join(' ') }.join(',')};
param #{@options[:bounds]}:=#{dimensions.zip(bounds).map { |v| v.join(' ') }.join(',')};
end;
END_OF_DATA
    File.open(@options[:data_file], 'w') do |file|
      file.puts data
    end
  end

  def get_result
    result_regex = /#{@options[:result]}:(.+)/
    variable_regex = /#{@options[:variable_name]}\[(\d+)\]:(.+)/
    result, assignment = 0, []
    
    File.open(@options[:output_file], 'r') do |file|
      file.each do |line|
        line.strip!
        if line =~ result_regex
          result = $1.to_f
        elsif line =~ variable_regex
          assignment[$1.to_i] = $2.to_i == 1
        end
      end
    end
    return [ result, assignment ]
  end
end
