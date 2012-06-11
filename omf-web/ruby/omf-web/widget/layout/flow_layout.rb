require 'omf-web/widget/abstract_widget'

module OMF::Web::Widget::Layout

  # Implements a layout which displays widgets in a 
  # horizontal layout which should wrap around.
  #
  class FlowLayout < OMF::Web::Widget::AbstractWidget
    
    def initialize(opts)
      super opts
      widgets = opts[:widgets]
      @widgets = widgets.collect {|w| OMF::Web::Widget.create_widget(w) }
    end

    def content()
      OMF::Web::Theme.require 'flow_renderer'
      OMF::Web::Theme::FlowRenderer.new(self, @widgets, @opts)
    end
      

    def collect_data_sources(ds_set)
      @widgets.each {|w| w.collect_data_sources(ds_set) }
      ds_set
    end
    
    def name
      @opts[:name] || "Unknown - Set :name property"
    end
    
    def layout?
      return true
    end
    

  end

end
