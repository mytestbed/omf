require 'omf-web/widget/abstract_data_widget'

module OMF::Web::Widget::Graph
  
  # Maintains the context for a particular graph rendering within a specific session.
  # It is primarily called upon maintaining communication with the browser and will
  # create the necessary html and javascript code for that.
  #
  class GraphWidget < OMF::Web::Widget::AbstractDataWidget
    
    def initialize(opts)
      unless opts
        raise "Missing widget options."
      end
      @name = opts[:name] || 'Unknown'
      
      wopts = opts[:wopts] || {}
      unless vizType = wopts[:viz_type]
        raise "Missing widget option ':viz_type' for widget '#{name}'"
      end
      opts[:name] = name
      opts[:js_url] = "graph/#{vizType}.js"
      opts[:js_class] = "OML.#{vizType}"
      #opts[:widget_class] = OMF::Web::Widget::AbstractDataWidget 
      
      super opts      
      @widget_type = vizType
    end
    



    
  end # GraphWidget
  
end
