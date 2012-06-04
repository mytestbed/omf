require 'omf-oml/table'

schema = [[:t, :int], [:volume, :float]]
table = OMF::OML::OmlTable.new 'downloads', schema

require 'omf_web'
OMF::Web.register_datasource table

skip_first_line = true
File.open("#{File.dirname(__FILE__)}/downloads.csv", "r").read.gsub!(/\r\n?/, "\n").each_line do |line|
  if skip_first_line
    skip_first_line = false
  else
    time, amount = line.split(",")
    #puts "date: #{date}::#{date2}"
    table.add_row [time.to_i, amount.to_f]
  end
end
