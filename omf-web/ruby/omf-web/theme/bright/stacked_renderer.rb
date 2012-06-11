
require 'omf-web/theme/bright/widget_chrome'

module OMF::Web::Theme
  
  class StackedRenderer
    
    def initialize(stacked_widget, widgets, active_index, opts)
      @stacked_widget = stacked_widget
      @widgets = widgets
      @active_index = active_index
      @helper = StackedRendererHelper.new(widgets, active_index, opts)
      @opts = opts
    end    
    
    def to_html()
      wp = "w#{@helper.object_id}"
      @opts[:menu] = @widgets.each_with_index.map do |w, i|
        wc = w.widget_type.split('/').inject([]) do |a, e| 
                a << (a.empty? ? e : "#{a[-1]}_#{e}") 
              end
        {
          :name => w.name, 
          :class => wc.join(' '), 
          :is_active => (@active_index == i), 
          :id => "#{wp}_l_#{i}",
          :js_function => 'OML.show_widget',
          :inner_class => wp,
          :index => i,
          :widget_id => w.dom_id
        }
      end     
      WidgetChrome.new(@stacked_widget, @helper, @opts).to_html
    end    
  end      

  class StackedRendererHelper < Erector::Widget
    
    def initialize(widgets, active_index, opts)
      super opts
      @widgets = widgets
      @active_index = active_index
    end    

    def content()
      #widget @active_widget
      widgets = @widgets  
      prefix = "w#{self.object_id}"
      @widgets.each_with_index do |w, i|
        style = i == @active_index ? '' : 'display:none'
        div :id => "#{prefix}_#{i}", :class => prefix, :style => style do
         rawtext w.content.to_html      
        end
      end 
    end
    
  end
end