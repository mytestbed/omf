
OMF::Web::Theme.require 'multi_card_page'
    
module OMF::Web::Tab::Graph

  class GraphPage < OMF::Web::Theme::MultiCardPage

    def initialize(widget, opts)
      super widget, :graph, OMF::Web::Widget::Graph, opts
    end
    
    def render_card_body
      return unless @widget
      widget @widget        
    end
    
  end # GraphCard
  
end