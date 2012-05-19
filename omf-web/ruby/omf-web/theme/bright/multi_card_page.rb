
OMF::Web::Theme.require 'page'

module OMF::Web::Theme
  
  class MultiCardPage < Page

    
    def initialize(widget, module_name, widget_names, opts)
      super opts
      @widget = widget
      @widget_names = widget_names
      @module_name = module_name
    end
    
    def render_card_nav
      div :id => 'card_nav' do
        ol do
          @widget_names.each_with_index do |name, i| 
            klass = (i == @card_id) ? 'selected' : nil
            li :class => klass do
              a name || 'unknown', :href => "/#{@module_name}/show?tid=#{i}&sid=#{Thread.current["sessionID"]}"
            end
          end
        end
      end            
    end # render_card_nav

    def render_card_body
      render_card_nav
      return unless @widget
      div :id => :card_content do 
        render_widget @widget
      end        
    end
    
    def collect_data_sources(dsa)
      @widget.collect_data_sources(dsa) if @widget
      dsa
    end
    
    
  end # SubMenuCard
  
end