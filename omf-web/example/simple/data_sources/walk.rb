

require 'omf-oml/table'

# Define a map with a trace on it
#

table = OMF::OML::OmlTable.new :walk, [:name, [:lon, :float], [:lat, :float], [:rssi, :float]]
table.add_row ['exp1', 151.197189, -33.895508, 20.0]
table.add_row ['exp1', 151.197327, -33.895512, 15.0]
table.add_row ['exp1', 151.197433, -33.895039, 12.0]
table.add_row ['exp1', 151.197159, -33.894833, 10.0]
table.add_row ['exp1', 151.196838, -33.894833, 12.0]
table.add_row ['exp1', 151.196762, -33.895271, 15.0]
table.add_row ['exp1', 151.196625, -33.895844, 10.0]
table.add_row ['exp1', 151.197266, -33.895947, 5.0]
table.add_row ['exp1', 151.197311, -33.895584, 14.0]

OMF::Web.register_datasource table


# # Register a graph widget to visualize a map
# #
# opts = {
  # #:data_sources => table,
  # #:viz_type => 'line_chart',
  # :wtype => 'graph',
  # :wopts => {
    # :viz_type => 'map2',
    # :data_sources => table,
    # :map_center => [151.197189, -33.895508],
    # :zoom => 18,
    # :mapping => {
      # :lat => {:property => :lat},
      # :lng => {:property => :lon},
      # :radius => {:property => :rssi, :min => 10},      
      # :fill_color => {:property => :rssi, :scale => 1.0 / 25, :color => 'red_yellow20_green()'},      
    # },
    # :margin => {
      # #:left => 100
    # }
  # }
# }
# OMF::Web::Widget::Graph.addGraph('Map', opts) 
# #OMF::Web::Widget.register('Amplitude', opts) 

