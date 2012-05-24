require 'omf-web/widget/abstract_data_widget'

module OMF::Web::Widget::Graph
  
  # Maintains the context for a particular graph rendering within a specific session.
  # It is primarily called upon maintaining communication with the browser and will
  # create the necessary html and javascript code for that.
  #
  class GraphWidget < OMF::Web::Widget::AbstractDataWidget
    #depends_on :css, "/resource/css/graph.css"
    
    #attr_reader :name, :opts
    
    def initialize(opts)
      unless opts
        raise "Missing widget options."
      end
      @name = opts[:name] || 'Unknown'
      # unless opts[:data_sources]
        # raise "Missing widget option ':data_sources' for widget '#{name}::#{opts.inspect}'"
      # end
      
      wopts = opts[:wopts] || {}
      unless vizType = wopts[:viz_type]
        raise "Missing widget option ':viz_type' for widget '#{name}'"
      end
  
      opts[:name] = name
      opts[:js_url] = "graph/#{vizType}.js"
      opts[:js_class] = "OML.#{vizType}"
      #opts[:widget_class] = OMF::Web::Widget::AbstractDataWidget 
      
      super opts

      # @gd = gd
      # @opts = gd.opts
      # @data_source = @opts[:data_source]
      # @name = @gd.name
      # @js_uri = @gd.vizType
      # @base_id = "g#{object_id.abs}"
      # @base_el = "\##{@base_id}"
#       
      # @js_var_name = "oml_#{object_id.abs}"
      # @js_func_name = 'OML.' + @js_uri.gsub("::", "_")
# 
      # @gopts = @gd.vizOpts.dup
      # #@gopts['session'] = session_id
      # # gopts['canvas'] = canvas if canvas
      # # gopts['data'] = data()
      # @gopts['base_el'] = @base_el
      
    end
    



    
  end # GraphWidget
  
end
