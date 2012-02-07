
require 'omf-oml/table'
require 'omf-oml/sql_source'

require 'omf-web/tabbed_server'

require 'omf-web/tab/graph/init'
require 'omf-web/widget/code/code'


include OMF::OML
#
# Configure graph displays
#
def init_graph(name, table, viz_type = 'table', viz_opts = {})
  #  i = 0
  def_viz_opts = {
    :schema => table.schema    
  }
  
  gopts = {
    :data_sources => table,
    :viz_type => viz_type,
    # :viz_type => 'map',    
    :wopts => def_viz_opts.merge(viz_opts)
  }
  OMF::Web::Widget::Graph.addGraph(name, gopts) 
end

Tables = {}

ep = OmlSqlSource.new("#{File.dirname(__FILE__)}/brooklynDemo.sq3")
ep.on_new_stream() do |stream|
  case stream.stream_name
  when 'wimaxmonitor_wimaxstatus'
    t = stream.capture_in_table(:oml_ts_server, :sender_hostname, :frequency, :rssi, :cinr)
    name = 'Wimax Status'
    init_graph(name, t, 'line_chart', 
      :mapping => {
        :x_axis => {:property => :oml_ts_server},
        :y_axis => {:property => :rssi},        
        :group_by => {:property => :sender_hostname}
      },
      :schema => t.schema,
      :ymax => -50
    )
  when 'GPSlogger_gps_data'
    t = stream.capture_in_table(:oml_ts_server, :oml_sender_id, :lat, :lon)
    name = 'Location'
    init_graph(name, t, 'map')
  end
  init_graph(name + ' (T)', t, 'table', :schema => t.schema.describe)
  #create_table(select, stream, 'table')
end
ep.run()

files = ['brooklyn_server.rb']

files.each do |fn|
  fp = "#{File.dirname(__FILE__)}/#{fn}"
  OMF::Web::Widget::Code.addCode(fn, :file => fp)
end


# Configure the web server
#
opts = {
  :page_title => 'Brooklyn Demo',  
#  :use_tabs => [:graph, :code, :log],
  :use_tabs => [:graph, :code],
  :theme => :bright
}
OMF::Web.start(opts)
