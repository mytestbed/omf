require 'omf-web/page'

module OMF::Web::Tab::Code
  
  class CodeCard < Page
    #depends_on :js, "/resource/js/d3.js"
  
    def initialize(widget, opts)
      super opts
      @widget = widget
    end
    
    def render_card_nav
      div :class => 'card_nav' do
        ul do
          OMF::Web::Widget::Code.each_with_index do |g, i| 
            klass = (i == @code_id) ? 'selected' : nil
            li :class => klass do
              a g.name, :href => "/code/show?wid=#{i}&sid=#{@session_id}"
            end
          end
        end
      end            
    end # render_card_nav
    
    def render_card_body
      return unless @widget
      
      widget @widget  
    end
  end # CodeCard
  
end
