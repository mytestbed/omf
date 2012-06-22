
require 'omf-web/theme/bright/widget_chrome'

module OMF::Web::Theme
  
  class TextRenderer < Erector::Widget
    
    def initialize(text_widget, content, opts)
      super opts
      @widget = text_widget
      @content = content
    end
    
    def content
      div :class => "text" do
        rawtext @content.to_html
      end
    end
      
  end 

end # OMF::Web::Theme
