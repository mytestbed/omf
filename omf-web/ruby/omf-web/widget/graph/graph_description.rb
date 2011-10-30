

module OMF::Web::Widget::Graph
  class GraphDescription < MObject
    
    attr_reader :name, :opts, :vizType, :vizOpts
    
    def initialize(name, vizType, opts)
      @name = name
      @vizType = vizType
      @opts = opts
      @vizOpts = @opts[:viz_opts] || {}
#      puts "VIZ_OPTS >>>> #{@vizOpts.inspect}"
    end
    
    def create_widget
      require 'omf-web/widget/graph/graph_widget'
      OMF::Web::Widget::Graph::GraphWidget.new(self)
    end
    
        
    private

  end # GraphDescription
end # OMF::Web::Widget::Graph
