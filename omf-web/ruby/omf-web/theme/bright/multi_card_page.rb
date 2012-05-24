
OMF::Web::Theme.require 'page'

module OMF::Web::Theme
  
  class MultiCardPage < Page

    
    def initialize(selected_widget, widgets, opts)
      super opts
      @selected_widget = selected_widget
      @widgets = widgets
    end
    
    def render_card_nav
      cname = @opts[:component_name]
      path = @opts[:path]
      div :id => 'card_nav' do
        ol do
          @widgets.each_with_index do |w, i| 
            klass = (w == @selected_widget) ? 'selected' : nil
            li :class => klass do
              a w.name || 'unknown', :href => "#{path}?tid=#{i}&sid=#{Thread.current["sessionID"]}"
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
    
    
  end # MultiCardPage
  
end