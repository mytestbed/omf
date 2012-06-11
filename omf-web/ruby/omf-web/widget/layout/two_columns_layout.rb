require 'omf-web/widget/abstract_widget'

module OMF::Web::Widget::Layout

  # Implements a layout which displays contained widgets in two columns.
  #
  class TwoColumnsLayout < OMF::Web::Widget::AbstractWidget

    def initialize(type, opts)
      super opts
      @left = (opts[:left] || []).map {|w| OMF::Web::Widget.create_widget(w)}
      @right = (opts[:right] || []).map {|w| OMF::Web::Widget.create_widget(w)}      
    end

    def content()
      OMF::Web::Theme.require 'two_columns_renderer'
      OMF::Web::Theme::TwoColumnsRenderer.new(@left, @right, @opts)      
    end

    def collect_data_sources(ds_set)
      @left.each {|w| w.collect_data_sources(ds_set) }
      @right.each {|w| w.collect_data_sources(ds_set) }
      ds_set
    end
    
    def name
      @opts[:name] || @active_widget.name
    end
    
    def layout?
      return true
    end
    
    
    # Return html for an optional widget tools menu to be added
    # to the widget decoration by the theme.
    # 
    def tools_menu()
      raise "Why are we here"
    end    



  end # StackedWidget

end
