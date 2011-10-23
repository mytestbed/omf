

module OMF::Web::Widget::Graph
  class GraphDescription < MObject
    
    attr_reader :name, :vizType, :vizOpts, :opts
    
    def initialize(name, vizType, opts)
      @name = name
      @vizType = vizType
      @opts = opts
      @vizOpts = @opts[:viz_opts] || {}
      puts "VIZ_OPTS >>>> #{@vizOpts.inspect}"
    end
        
    private

  end # GraphDescription
end # OMF::Web::Widget::Graph
