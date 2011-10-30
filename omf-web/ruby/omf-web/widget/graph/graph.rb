
module OMF::Web; module Widget; module Graph
end; end; end

require 'omf-web/widget/graph/graph_description'

module OMF::Web::Widget::Graph
  
  @@graphs = []
  @@sessions = {}
  
  def self.configure(options = {})
    opts = options.dup
    opts[:graphs] = @@graphs
  
    currDir = File.dirname(__FILE__)
    opts[:resourcePath].insert(0, currDir)
    #puts ">>>>>>>>>>> #{ opts[:ResourcePath]}"
  #          server.mount('/graph3/resource', ::OMF::Common::Web::ResourceHandler, opts)
  end
  
  # Register a graph which can be visualized through a +GraphWidget+
  #
  # name - Name of graph
  # opts -
  #   :viz_type - Type of graph, reqires equally named js file describing how it should be rendered
  #   :???
  # 
  def self.addGraph(name, opts = {})
    vizType = opts[:viz_type]
    raise "Missing :viz_type in 'addGraph'" unless vizType
    @@graphs << (gd = GraphDescription.new(name, vizType, opts))
    gd
  end
  
  # def self.addNetworkGraph(name, opts = {}, &netProc)
    # g = {}
    # g[:name] = name
    # g[:gopts] = opts.dup
    # g[:netProc] = netProc
    # @@graphs << g
  # end
  
  def self.[](id)
    @@graphs[id]
  end        
  
  def self.count
    @@graphs.length
  end        
  
  def self.each_with_index
    @@graphs.each_index do |i|
      yield @@graphs[i], i
    end
  end
end # OMF::Web::Widget::Graph
