
module OMF::Web; module Widget; module Graph
end; end; end

require 'omf-web/widget/graph/graph_widget'

module OMF::Web::Widget::Graph
  
  @@graphs = []
  @@sessions = {}
  
  def self.configure(options = {})
    opts = options.dup
    opts[:graphs] = @@graphs
  
    currDir = File.dirname(__FILE__)
    opts[:resourcePath].insert(0, currDir)
  end
  
  # Register a graph which can be visualized through a +GraphWidget+
  #
  # name - Name of graph
  # opts -
  #   :viz_type - Type of graph, reqires equally named js file describing how it should be rendered
  #   :???
  # 
  def self.addGraph(name, opts = {})
    
    wopts = opts[:wopts] || {}
    unless wopts[:data_sources]
      raise "Missing widget option ':data_sources' for widget '#{name}'"
    end
    
    unless vizType = wopts[:viz_type]
      raise "Missing widget option ':viz_type' for widget '#{name}'"
    end

    opts[:name] = name
    opts[:js_url] = "graph/#{vizType}.js"
    opts[:js_class] = "OML.#{vizType}"
    opts[:widget_class] = OMF::Web::Widget::AbstractDataWidget 
    @@graphs << opts
    opts
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
end # OMF::Web::Widget::Graph
