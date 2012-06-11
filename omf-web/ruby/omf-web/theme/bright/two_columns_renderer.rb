
require 'omf-web/theme/bright/widget_chrome'

module OMF::Web::Theme
  
  class TwoColumnsRenderer < Erector::Widget
    
    DEFAULT_LAYOUT = '66_33'
    
    @@layout2class = {
      '50_50' => "yui-g",
      '66_33' => "yui-gc",
      '33_66' => "yui-gd",
      '75_25' => "yui-ge",
      '25_75' => "yui-gf"
    }
      
    def initialize(lwidgets, rwidgets, opts)
      super opts
      # looking for something like: 'layout/two_columns/50_50'
      layout = (opts[:type].split('/')[2] || DEFAULT_LAYOUT).to_s
      unless @layout_class = @@layout2class[layout]
        warn "Unknown layout '#{layout}'"
        @layout_class = @@layout2class[DEFAULT_LAYOUT]
      end
      
      @lwidgets = lwidgets || []
      @rwidgets = rwidgets || []
      @opts = opts
    end
    
    def content

      div :class => @layout_class do
        div :class => "yui-u first column column-left" do
          render_left
        end
        div :class => "yui-u column column-right" do
          render_right
        end
      end
    end
    
    def render_left
      @lwidgets.each do |w|
        render_widget w
      end
    end

    def render_right
      @rwidgets.each do |w|
        render_widget w
      end
    end
    
    def render_widget(w)
      r = w.content
      unless w.layout?
        r = WidgetChrome.new(w, r, @opts)
      end
      rawtext r.to_html      
    end    

  end # TwoColumnPage

end # OMF::Web::Theme
