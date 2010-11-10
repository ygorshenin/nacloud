# Author: Yuri Gorshenin

# Class represents sets of functions, that helps
# obtain well-look representation of auction allocation
class HTMLAllocation
  # returns allocation representation as html table
  def self.represent(allocation)
    header = "<tr><th>Supplier</th><th>Bids</th></tr>"
    rows = allocation.map { |supplier_id, assigned| "<tr>#{get_html_table_row(supplier_id, assigned)}</tr>" }.join("\n")
    table = <<END_OF_TABLE
<table border="1">
#{header}
#{rows}
</table>
END_OF_TABLE
    table
  end

  # for single demander returns string like
  # "ygorshenin (dimensions: [10, 20, 30], pay: 999.999)"
  def self.stringify_bid(demander, bid)
    "#{demander.get_id} (supplier id: #{bid[:supplier_id].inspect}, dimensions: #{bid[:dimensions].inspect}, pay: #{bid[:pay]})"
  end

  private

  # returns html representation of single table row
  # looks like
  # <td>fetetriste</td><td>ygorshenin (...), david_it21 (...), ... </td>
  def self.get_html_table_row(supplier_id, assigned)
    values = assigned.values.map { |v| stringify_bid(v[:demander], v[:bid]) }.join('<br>')
    "<td>#{supplier_id}</td><td>#{values}</td>"
  end
end
