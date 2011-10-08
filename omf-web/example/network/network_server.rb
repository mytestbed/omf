

require 'omf-web/tabbed_server'
require 'omf-common/oml/network'
require 'omf-web/tab/graph/init'

# Define data sources
#


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

# class NetworkDescription
  # def initialize(nodes, links)
    # @nodes = nodes
    # @links = links
  # end
#   
  # def update(context)
    # @nodes[0]["capacity"] = rand
    # @links[0]["load"] = rand
    # nw = {:nodes => @nodes, :links => @links}
    # nw
  # end
#   
  # def init(context)
    # update(context)
  # end
# end

include OMF::Common::OML
  
nw = OmlNetwork.new 
nw.create_node :n0, :x => 0.2, :y => 0.2, :capacity =>  0.3
nw.create_node :n1, :x => 0.5, :y => 0.5, :capacity =>  0.5
nw.create_node :n2, :x => 0.6, :y => 0.8, :capacity =>  0.8

nw.create_link :l01, :n0, :n1, :load => 0.8
nw.create_link :l12, :n1, :n2, :load => 0.4


Thread.new do
  begin
    loop do
      sleep 2
      nw.transaction do 
        nw.links.each do |link|
          l = link[:load] + 0.2
          link[:load] = l > 1 ? 0.2 : l
        end
        nw.nodes.each do |node|
          c = node[:capacity] + 0.2
          node[:capacity] = c > 1 ? 0.2 : c
        end
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
        m = nw.nodes.first
        x = m[:x] + 0.05
        m[:x] = x > 0.9 ? 0.1 : x
      end
    end
  rescue Exception => ex
    puts ex
    puts ex.backtrace.join("\n")
  end
end


init_graph 'Simple', nw, 'network'






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
