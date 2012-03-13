

require 'omf-oml/network'

require 'omf-web/tabbed_server'
require 'omf-web/tab/graph/init'
require 'omf-web/widget/code/code'

require 'omf-oml/table'
require 'omf-oml/sql_source'

include OMF::OML


# Define data sources
#
puts "ATGV:  #{ARGV.inspect}"
$db_name = ARGV[0] || "/var/lib/oml2/gec12_demo_pgeni.sq3"

#
# Configure graph displays
#
def init_graph(name, data_sources, viz_type = 'network', opts = {})
  #  i = 0
  def_viz_opts = {
    #:schema => data.schema    
  }
  # end
  gopts = {
    :dynamic => {
      :updateInterval => 1
    },
    :viz_type => viz_type,
    # :viz_type => 'map',    
    :wopts => def_viz_opts.merge(opts)
  }
  if data_sources
    unless data_sources.kind_of? Hash
      data_sources = {:default => data_sources}
    end 
    gopts[:data_sources] = data_sources
  end    
  
  OMF::Web::Widget::Graph.addGraph(name, gopts) 
end


require 'omf-web/tab/two_column/two_column_service'
$lwidgets = []
$rwidgets = []
# OMF::Web::Tab.register_tab(
    # :id => :overview,
    # :name => 'Overview', 
    # :priority => 999, 
    # :class => OMF::Web::Tab::TwoColumn::TwoColumn,
    # :opts => { 
      # :layout => :layout_66_33,
      # :left => $lwidgets,
      # :right => $rwidgets
    # }
# )


files = ['demo-gec13-v3.rb', 'iperf_app.rb', 'system_monitor.rb', 'visualization.rb', 
      'sys_mon_viz.rb', 'resources/js/graph/demo_topo.js']

files.each do |fn|
  fp = "#{File.dirname(__FILE__)}/#{fn}"
  OMF::Web::Widget::Code.addCode(fn.split('/')[-1], :file => fp)
end
load "#{File.dirname(__FILE__)}/visualization.rb"
load "#{File.dirname(__FILE__)}/sys_mon_viz.rb"

#ep = OmlSqlSource.new($db_name, :check_interval => 1.0)
ep = OmlSqlSource.new($db_name)
ep.on_new_stream() do |stream|
  begin
    f = stream.stream_name.to_sym
    if t = self.send(f, stream)
      #puts "SCHEMA>>> #{t.schema.describe.inspect}"
      init_graph("#{t.name} (T)", t, 'table', :schema => t.schema.describe)
    end
  rescue NoMethodError
    MObject.error(:oml, "Don't know what to do with table '#{stream.stream_name}'")
  end
end

# Converting blobs into U64 numbers
class String
  def u64
    self.unpack('C*').inject(0) do |a, b| a * 256 + b end
  end
end

ep.run(5)

# Configure the web server
#
opts = {
  :sslNOT => {
    :cert_chain_file => "#{File.dirname(__FILE__)}/debug/server_chain.crt", 
    :private_key_file => "#{File.dirname(__FILE__)}/debug/server.key", 
    :verify_peer => false
  },
  :page_title => "Simple GIMI Experiment - #{$db_name.match('.*gec13demo-(.*)\.sq3')[1]}",
  :use_tabs => [:overview, :graph, :code, :log],
  :use_tabs => [:graph, :code],
  :theme => :bright
}
OMF::Web.start(opts)
