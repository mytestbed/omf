require 'omf-web/widget/abstract_widget'

module OMF::Web::Widget::Layout

  # Implements a layout which displays contained widgets in a single columns.
  #
  class OneColumnLayout < OMF::Web::Widget::AbstractWidget

    def initialize(opts)
      super opts
      @widgets = (opts[:widgets] || []).map {|w| OMF::Web::Widget.create_widget(w)}
    end

    def content()
      OMF::Web::Theme.require 'one_column_renderer'
      OMF::Web::Theme::OneColumnRenderer.new(@widgets, @opts)      
    end

    def collect_data_sources(ds_set)
      @widgets.each {|w| w.collect_data_sources(ds_set) }
      ds_set
    end
    
    def name
      @opts[:name] || @opts[:title]
    end
    
    def layout?
      return true
    end

  end 

end
