

require 'omf-oml/network'

require 'omf-web/tabbed_server'
require 'omf-web/tab/graph/init'

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


include OMF::OML
  
nw = OmlNetwork.new 
nw.create_node :n0, :x => 0.2, :y => 0.2, :capacity =>  0.3
nw.create_node :n1, :x => 0.5, :y => 0.5, :capacity =>  0.5
nw.create_node :n2, :x => 0.6, :y => 0.8, :capacity =>  0.8

nw.create_link :l01, :n0, :n1, :load => 0.8
nw.create_link :l12, :n1, :n2, :load => 0.4

require 'omf-oml/table'

s = OmlSchema.new [[:ts, Float], [:name, String], [:capacity, Integer]]
node_table = OMF::OML::OmlTable.new('nodes', s)
start = Time.now
node_table.on_row_added(node_table) do |row|
  #puts "ROW>>> #{row.inspect}"
  t2, node_name, capacity = row
  nw.node(node_name)[:capacity] = capacity
  # uset.each do |el|
    # if el.node?
      # node_table.add_row [t, el.name, el[:capacity]]
    # end
  # end
end

Thread.new do
  begin
    start = Time.now
    loop do
      sleep 2
      nw.transaction do 
        nw.links.each do |link|
          l = link[:load] + 0.2
          link[:load] = l > 1 ? 0.2 : l
        end
      end
        
      t = Time.now - start
      nw.nodes.each do |node|
        c = node[:capacity] + 0.2
        c = c > 1 ? 0.2 : c
        node_table.add_row [t, node.name, c]
      end
    end
  rescue Exception => ex
    puts ex
    puts ex.backtrace.join("\n")
  end
end

# Move one node
Thread.new do
  begin
    loop do
      sleep 0.5
      nw.transaction do 
        m = nw.node(:n2)
        x = m[:x] + 0.05
        m[:x] = x > 0.9 ? 0.1 : x
      end
    end
  rescue Exception => ex
    puts ex
    puts ex.backtrace.join("\n")
  end
end


init_graph 'Network', nw, 'network', {
  :mapping => {
    :node => {
      :radius => {:value => :capacity, :scale => 20, :min => 4},
      :fill_color => {:value => :capacity, :scale => :green_yellow80_red}
    },
    :link => {
      :stroke_width => {:value => :load, :scale => 20},
      :stroke_color => {:value => :load, :scale => :green_yellow80_red}
    }
  }
}
init_graph 'Nodes', node_table, 'line_chart', {
  :schema => node_table.schema.describe,
  :mapping => {:x_axis => :ts, :y_axis => :capacity, :group_by => :name}
}


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
