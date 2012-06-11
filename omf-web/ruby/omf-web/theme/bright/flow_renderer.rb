
require 'omf-web/theme/bright/widget_chrome'

module OMF::Web::Theme
  
  class FlowRenderer < Erector::Widget
    
    def initialize(layout_widget, widgets, opts)
      super opts
      @layout_widget = layout_widget
      @widgets = widgets || []
      @opts = opts
    end
    
    def content
      # This is a very simple way of determining the width settings.
      width = (100 / @widgets.size).to_i
      div :class => 'flow_layout' do
        @widgets.each do |w|
          div :class => 'flow_layout_single', :style => "width:#{width}%; float:left" do
            render_widget w
          end
        end
      end     
    end

    def render_widget(w)
      r = w.content
      unless w.layout?
        r = WidgetChrome.new(w, r, @opts)
      end
      rawtext r.to_html      
    end    
    
    
  end 
  
end