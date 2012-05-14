

require 'omf-oml/network'
require 'omf-oml/table'

include OMF::OML
  
nw = OmlNetwork.new
nw.node_schema [[:x, :float], [:y, :float], [:capacity, :float]]
nw.create_node :n0, :x => 0.2, :y => 0.2, :capacity =>  0.3
nw.create_node :n1, :x => 0.6, :y => 0.6, :capacity =>  0.5
nw.create_node :n2, :x => 0.8, :y => 0.3, :capacity =>  0.8

nw.link_schema [[:load, :float]]
nw.create_link :l01, :n0, :n1, :load => 0.8
nw.create_link :l12, :n1, :n2, :load => 0.4
nw.create_link :l21, :n2, :n1, :load => 0.9

opts = {
  #:data_sources => table,
  #:viz_type => 'line_chart',
  :wtype => 'graph',
  :wopts => {
    :viz_type => 'network2',
    :data_sources => nw.to_tables,
    :mapping => {
      :nodes => {
        :x => {:property => :x},
        :y => {:property => :y},
        :radius => {:property => :capacity, :scale => 20, :min => 4},
        :fill_color => {:property => :capacity, :color => :green_yellow80_red}
      },
      :links => {
        :stroke_width => {:property => :load, :scale => 20},
        :stroke_color => {:property => :load, :color => :green_yellow80_red}
      }
    }
  }
}
OMF::Web::Widget::Graph.addGraph('Network', opts) 
#OMF::Web::Widget.register('Amplitude', opts) 
