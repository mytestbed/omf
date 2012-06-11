
require 'omf-web/theme/bright/widget_chrome'

module OMF::Web::Theme
  
  class OneColumnRenderer < Erector::Widget
    
    def initialize(widgets, opts)
      super opts
      @widgets = widgets
    end
    
    def content
      div :class => 'one_column' do
        @widgets.each do |w|
          render_widget w
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

  end # OneColumnRenderer

end # OMF::Web::Theme
