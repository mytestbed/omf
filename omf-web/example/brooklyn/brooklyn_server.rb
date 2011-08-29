

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
def init_graph(table, viz_type = 'table', viz_opts = {})
  #  i = 0
  def_viz_opts = {
    :schema => table.schema    
  }
  
  gopts = {
    :data_source => table,
    :viz_type => viz_type,
    # :viz_type => 'map',    
    :viz_opts => def_viz_opts.merge(viz_opts)
  }
  OMF::Web::Widget::Graph.addGraph(table.name, gopts) 
end

Tables = {}

ep = OMF::Common::OML::OmlSqlSource.new("#{File.dirname(__FILE__)}/brooklynDemo.sq3")
ep.on_new_stream() do |stream|
  #puts ">>>>>>>>>>>> New stream #{stream.stream_name}: #{stream.schema.names.join(', ')}"
  #puts ">>>>>>>>>>>> New stream #{stream.inspect}"
  case stream.stream_name
  when 'wimaxmonitor_wimaxstatus'
    t = stream.capture_in_table(:oml_ts_server, :sender_hostname, :frequency, :rssi, :cinr)
    init_graph(t, 'line_chart_fc', 
      :mapping => {:group_by => :sender_hostname, :x_axis => :oml_ts_server, :y_axis => :rssi})
    #create_table([:oml_ts_server, :rssi], stream, 'line_chart')
  when 'GPSlogger_gps_data'
    t = stream.capture_in_table(:oml_ts_server, :oml_sender_id, :lat, :lon)
    init_graph(t, 'map')
  end
  init_graph(t, 'table')
  #create_table(select, stream, 'table')
end
ep.run()




# Configure the web server
#
opts = {
  :sslNOT => {
    :cert_chain_file => "#{File.dirname(__FILE__)}/debug/server_chain.crt", 
    :private_key_file => "#{File.dirname(__FILE__)}/debug/server.key", 
    :verify_peer => false
  },
  :page_title => 'Brooklyn Demo'
  # :tabs => {
    # :foo => {:name => 'Foo', :order => 1, :class => Foo},
    # :goo => {:name => 'Goo', :order => 3}
  # }
}
OMF::Web.start(opts)
