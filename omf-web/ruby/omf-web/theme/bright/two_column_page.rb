

module OMF::Web::Theme
  
  class TwoColumnPage < Page
    
    DEFAULT_LAYOUT = :layout_66_33
    
    @@layout2class = {
      :layout_66_33 => "yui-gc",
      :layout_33_66 => "yui-gd",
      :layout_75_25 => "yui-ge",
      :layout_25_75 => "yui-gf"
    }
      
    def initialize(lwidgets, rwidgets, opts)
      super opts
      @layout = opts[:layout] || DEFAULT_LAYOUT
      @lwidgets = lwidgets
      @rwidgets = rwidgets      
    end
    
    def render_card_body
      klass = @@layout2class[@layout]
      unless klass
        warn "Unknown layout '#{@layout}"
        klass = @@layout2class[DEFAULT_LAYOUT]
      end

      div :class => klass do
        div :class => "yui-u first" do
          render_left
        end
        div :class => "yui-u" do
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

  end # TwoColumnPage

end # OMF::Web::Theme
