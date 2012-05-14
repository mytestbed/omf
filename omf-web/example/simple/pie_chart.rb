

require 'omf-oml/table'

# Define a simple pie
#

table = OMF::OML::OmlTable.new 'pie', [:name, [:count, :int]]
table.add_row ['mouse', 1]
table.add_row ['cat', 2]
table.add_row ['dog', 3]


# Register a graph widget to visualize the table as a line chart
#
opts = {
  #:data_sources => table,
  #:viz_type => 'line_chart',
  :wtype => 'graph',
  :wopts => {
    :viz_type => 'pie_chart',
    :data_sources => table,
    :mapping => { 
      :value => :count,
      :fill_color => 'category10()',
      :label => :name
    },
    :margin => {
      #:left => 100
    }
  }
}
OMF::Web::Widget::Graph.addGraph('Pie', opts) 
#OMF::Web::Widget.register('Amplitude', opts) 

