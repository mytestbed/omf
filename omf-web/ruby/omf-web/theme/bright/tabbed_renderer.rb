
require 'omf-web/theme/bright/widget_chrome'

module OMF::Web::Theme
  
  class TabbedRenderer < Erector::Widget
    
    def initialize(layout_widget, widgets, opts)
      super opts
      @layout_widget = layout_widget
      @widgets = widgets || []
      @opts = opts
    end
    
    def content
      selected = get_selected_widget()
      div :class => 'tabbed_layout' do
        div :id => 'card_nav', :class => 'navigation' do
          render_card_nav(selected)
        end
        if selected
          div :id => :card_content, :class => 'content' do 
            render_widget selected
          end
        else
          div :class => 'flash_alert flash' do
            text "Nothing to display"
          end
        end
      end     
    end

    def render_card_nav(selected)
      cname = @opts[:component_name]
      path = @opts[:path]

      ol do
        @widgets.each_with_index do |w, i| 
          klass = (w == selected) ? 'selected' : nil
          li :class => klass do
            a w.name || 'unknown', :href => "#{path}?tid=#{i}&sid=#{Thread.current["sessionID"]}"
          end
        end
      end            
    end # render_card_nav

    def render_widget(w)
      r = w.content
      unless w.layout?
        r = WidgetChrome.new(w, r, @opts)
      end
      rawtext r.to_html      
    end    
    
    def get_selected_widget()
      # TODO: THIS NEEDS FIXING - WE NEED TO GET REQ OBJECT THROUGH THREAD
      req = Thread.current["top_renderer"].opts[:request]
      puts ">>>> #{req.params['tid']}"
      # opts[:tab] = tab_id = tab[:id]
      # opts[:request] = req      
      tid = (req.params['tid'] || 0).to_i
      return @widgets[tid]
    end
    
  end # TabbedRenderer
  
end