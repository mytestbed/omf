
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
table = OMF::OML::OmlTable.new 'samples', schema #, :max_size => 30
irwin_hall_distribution 10000, 10, table, 'd1'


# Register a graph widget to visualize the table as a histogram
#
opts = {
  :wtype => 'graph',
  :dynamic => {:updateInterval => 1},
  :wopts => {
    :viz_type => 'histogram',
    :data_sources => table,
    #:dynamic => true,
    :mapping => { :x_axis => :t, :y_axis => :amplitude, :group_by => :device },
    :mapping => {}
  }
  
}
OMF::Web::Widget::Graph.addGraph('Histogram', opts) 
#OMF::Web::Widget.register('Amplitude', opts) 
