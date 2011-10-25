require 'omf-web/page'

module OMF::Web::Tab
  
  class WidgetPage < Page
    
    def initialize(widget, opts)
      super opts
      @widget = widget
    end
    
    # def render_card_nav
      # div :class => 'card_nav' do
        # ul do
          # @items_class.each_with_index do |g, i| 
            # klass = (i == @widget_id) ? 'selected' : nil
            # li :class => klass do
              # a g.name, :href => "/#{@module_name}/show?wid=#{i}&sid=#{@session_id}"
            # end
          # end
        # end
      # end            
    # end # render_card_nav
    
    def render_card_body
      return unless @widget
      widget @widget        
    end
  end # Widget
  
end

