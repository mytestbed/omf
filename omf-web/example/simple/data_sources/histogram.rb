
require 'omf-oml/table'

# Create a table containing 'amplitude' measurements taken at a certain time for two different 
# devices.
#

def irwin_hall_distribution(n, m, table, name) 
  n.times do |i|
    s = 0
    m.times do |j|
      s += Kernel.rand();
    end
    table.add_row [i, name, s]
  end
end

schema = [[:t, :int], [:device, :string], [:value, :float]]
table = OMF::OML::OmlTable.new 'irwin_hall', schema #, :max_size => 30
irwin_hall_distribution 10000, 10, table, 'd1'

require 'omf_web'
OMF::Web.register_datasource table

