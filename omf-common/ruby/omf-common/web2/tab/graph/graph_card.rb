require 'omf-common/web2/page'

module OMF::Common::Web2::Graph
  
  class GraphCard < Page
    depends_on :js, "/resource/js/d3.js"
    depends_on :css, "/resource/css/graph.css"
  
    def initialize(graph_widget, opts)
      super opts
      @gwidget = graph_widget
    end
    
    def render_card_nav
      div :class => 'card_nav' do
        ul do
          ::OMF::Common::Web2::Graph.each_with_index do |g, i| 
            klass = (i == @graph_id) ? 'selected' : nil
            li :class => klass do
              a g.name, :href => "/graph/show?gid=#{i}&sid=#{@session_id}"
            end
          end
        end
      end            
    end # render_card_nav
    
    def render_card_body
      return unless @gd
      
      if (prefix = @gd.opts[:prefix])
        p prefix
      end
      
      widget @gwidget        
      
      if (postfix = @gd.opts[:postfix])
        p postfix
      end
  
    end
  end # GraphCard
  
end
