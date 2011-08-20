
module OMF::Common::Web2; module Widget; module Graph
end; end; end

require 'omf-common/web2/widget/graph/graph_description'

module OMF::Common::Web2::Widget::Graph
  
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
  
  def self.addGraph(name, opts = {})
    vizType = opts[:viz_type]
    raise "Missing :viz_type in 'addGraph'" unless vizType
    @@graphs << GraphDescription.new(name, vizType, opts)
  end
  
  def self.addNetworkGraph(name, opts = {}, &netProc)
    g = {}
    g[:name] = name
    g[:gopts] = opts.dup
    g[:netProc] = netProc
    @@graphs << g
  end
  
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
end # OMF::Common::Web2::Widget::Graph
