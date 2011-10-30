

require 'omf-oml/network'

require 'omf-web/tabbed_server'
require 'omf-web/tab/graph/init'
require 'omf-web/widget/code'

# Define data sources
#


#
# Configure graph displays
#
def init_graph(name, data, viz_type = 'network', opts = {})
  #  i = 0
  def_viz_opts = {
    #:schema => table.schema    
  }
  
  gopts = {
    :data_source => data,
    :dynamic => {
      :updateInterval => 1
    },
    :viz_type => viz_type,
    # :viz_type => 'map',    
    :viz_opts => def_viz_opts.merge(opts)
  }
  OMF::Web::Widget::Graph.addGraph(name, gopts) 
end

files = ['visualization.rb', 'oml.rb']

files.each do |fn|
  fp = "#{File.dirname(__FILE__)}/#{fn}"
  puts "FILE>>> #{fp}"
  OMF::Web::Widget::Code.addCode(fn, :file => fp)
  load(fp) 
end





# Configure the web server
#
opts = {
  :sslNOT => {
    :cert_chain_file => "#{File.dirname(__FILE__)}/debug/server_chain.crt", 
    :private_key_file => "#{File.dirname(__FILE__)}/debug/server.key", 
    :verify_peer => false
  },
  :page_title => 'Mobility First',
  :use_tabs => [:graph, :code, :log],
  :theme => :traditional
}
OMF::Web.start(opts)
