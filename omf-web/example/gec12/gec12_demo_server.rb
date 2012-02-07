

require 'omf-oml/network'

require 'omf-web/tabbed_server'
require 'omf-web/tab/graph/init'
require 'omf-web/widget/code/code'

# Define data sources
#
puts "ATGV:  #{ARGV.inspect}"
$db_name = ARGV[0] || "/var/lib/oml2/gec12_demo_pgeni.sq3"

#
# Configure graph displays
#
def init_graph(name, data_sources, viz_type = 'network', opts = {})
  #  i = 0
  unless data_sources.kind_of? Hash
    data_sources = {:default => data_sources}
  end 
  def_viz_opts = {
    #:schema => data.schema    
  }
  # end
  gopts = {
    :data_sources => data_sources,
    :dynamic => {
      :updateInterval => 1
    },
    :viz_type => viz_type,
    # :viz_type => 'map',    
    :wopts => def_viz_opts.merge(opts)
  }
  OMF::Web::Widget::Graph.addGraph(name, gopts) 
end


require 'omf-web/tab/two_column/two_column_service'
$lwidgets = []
$rwidgets = []
OMF::Web::Tab.register_tab(
    :id => :overview,
    :name => 'Overview', 
    :priority => 999, 
    :class => OMF::Web::Tab::TwoColumn::TwoColumn,
    :opts => { 
      :layout => :layout_66_33,
      :left => $lwidgets,
      :right => $rwidgets
    }
)


files = ['gec12-53.rb', 'visualization.rb', 'gec12_demo_server.rb']

files.each do |fn|
  fp = "#{File.dirname(__FILE__)}/#{fn}"
  OMF::Web::Widget::Code.addCode(fn, :file => fp)
end
load "#{File.dirname(__FILE__)}/visualization.rb"


# Configure the web server
#
opts = {
  :sslNOT => {
    :cert_chain_file => "#{File.dirname(__FILE__)}/debug/server_chain.crt", 
    :private_key_file => "#{File.dirname(__FILE__)}/debug/server.key", 
    :verify_peer => false
  },
  :page_title => 'Mobility First',
  :use_tabs => [:overview, :graph, :code, :log],
  :theme => :bright
}
OMF::Web.start(opts)
