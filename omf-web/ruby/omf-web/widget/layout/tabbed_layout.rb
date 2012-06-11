require 'omf-web/widget/abstract_widget'

module OMF::Web::Widget::Layout

  # Implements a layout which displays only one of the widget it contains
  # but provides theme specific means to switch between them.
  #
  class TabbedLayout < OMF::Web::Widget::AbstractWidget
    attr_reader :active_index
    
    def initialize(opts)
      super opts
      widgets = opts[:widgets]
      @widgets = widgets.collect {|w| OMF::Web::Widget.create_widget(w) }
    end

    def content()
      OMF::Web::Theme.require 'tabbed_renderer'
      OMF::Web::Theme::TabbedRenderer.new(self, @widgets, @opts)
    end
      

    def collect_data_sources(ds_set)
      @widgets.each {|w| w.collect_data_sources(ds_set) }
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
    # def tools_menu()
      # widgets = @widgets
      # active_index = @active_index
      # wp = "w#{self.object_id}"
      # Erector.inline do
        # ol :class => :widget_tools_menu do
          # widgets.each_with_index do |w, i|
            # is_active = (i == active_index)
            # lopts = {}
            # lopts[:class] = "#{w.widget_type}#{is_active ? ' current' : ''}"
            # lopts[:id] = "#{wp}_l_#{i}"
            # li lopts do
              # a :href => "javascript:OML.show_widget('#{wp}', #{i}, '#{w.base_id}');"  do
                # span w.name, :class => :widget_tools_menu
              # end
            # end
          # end
          # li :class => 'info' do
            # a :id => "#{wp}_info_a", :href => "#"  do
              # span 'Info' , :class => :widget_tools_menu
            # end
          # end          
        # end
      # end.to_html
    # end    



  end # StackedWidget

end
