require 'omf-web/theme/abstract_page'

module OMF::Web::Theme
  
  # This page renders a widget with minimal decorations. It's primary 
  # role is to allow other web entities to embed a widget via an iframe.
  #
  # Note, the 'w' option allows the caller to set the width of the page
  #
  class WidgetPage < OMF::Web::Theme::AbstractPage
    
    depends_on :css, '/resource/css/theme/bright/reset-fonts-grids.css'
    depends_on :css, "/resource/css/theme/bright/bright.css"
   
    depends_on :script, %{
      OML.show_widget = function(opts) {
        var prefix = opts.inner_class;
        var index = opts.index;
        var widget_id = opts.widget_id;
        
        $('.' + prefix).hide();
        $('#' + prefix + '_' + index).show();
        
        var current = $('#' + prefix + '_l_' + index);
        current.addClass('current');
        current.siblings().removeClass('current');
         
        var widget = OML.widgets[widget_id];
        if (widget) widget.resize().update();
      };
    }
       
    def content
      style = ''
      if width = @request.params['w']
        style = 'width:' + width
      end
      div :class => 'widget_container', :style => style  do
        render_body
      end
    end
    
    def render_body
      render_flash
      render_card_body
    end
    
    def render_card_body
      return unless @widget
      Thread.current["top_renderer"] = self
      if @widget.layout?
        rawtext @widget.content.to_html
      else
        div :class => 'widget_body' do
          rawtext @widget.content.to_html
        end
      end
    end
    
  end # class WidgetPage
end # OMF::Web::Theme