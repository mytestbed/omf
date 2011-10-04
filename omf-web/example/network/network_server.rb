

require 'omf-web/tabbed_server'

# Define data sources
#

# This one creates a data stream internally
require 'omf-common/oml/oml_table'


# This defines an OML endpoint. It expects a stream from the 
# OML example generator on port 3000.
#
# % ./oml_example --oml-config config_text_stream.xml
#
require 'omf-common/oml/oml_sql_source'
require 'omf-web/tab/graph/init'
#
# Configure graph displays
#
def init_graph(name, data, viz_type = 'network', viz_opts = {})
  #  i = 0
  def_viz_opts = {
    #:schema => table.schema    
  }
  
  gopts = {
    :data_source => data,
    :dynamic => true,
    :viz_type => viz_type,
    # :viz_type => 'map',    
    :viz_opts => def_viz_opts.merge(viz_opts)
  }
  OMF::Web::Widget::Graph.addGraph(name, gopts) 
end

class NetworkDescription
  def initialize(nodes, links)
    @nodes = nodes
    @links = links
  end
  
  def update(context)
    @nodes[0]["capacity"] = rand
    @links[0]["load"] = rand
    nw = {:nodes => @nodes, :links => @links}
    nw
  end
  
  def init(context)
    update(context)
  end
end

nw = NetworkDescription.new([
    {"name" => "n1","x" => 100,"y" => 30, "capacity" =>  0.3},
    {"name" => "n2","x" => 60,"y" => 160, "capacity" =>  0.5},
    {"name" => "n3","x" => 150,"y" => 210, "capacity" =>  0.8}
  ],
  [
    {"from" => 1,"to" => 0,"load" => 0.3},
    {"from" => 2,"to" => 0,"load" => 0.8}
  ]
)
init_graph 'foo', nw, 'network'






# Configure the web server
#
opts = {
  :sslNOT => {
    :cert_chain_file => "#{File.dirname(__FILE__)}/debug/server_chain.crt", 
    :private_key_file => "#{File.dirname(__FILE__)}/debug/server.key", 
    :verify_peer => false
  },
  :page_title => 'Network Demo'
  # :tabs => {
    # :foo => {:name => 'Foo', :order => 1, :class => Foo},
    # :goo => {:name => 'Goo', :order => 3}
  # }
}
OMF::Web.start(opts)
