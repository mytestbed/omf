require 'omf-web/widget/abstract_widget'

module OMF::Web::Widget

  # Supports widgets which visualize the content of a +Table+
  # which may also dynamically change.
  #
  class StackedWidget < AbstractWidget

    # Widget to support flipping among the widgets
    # declared in 'widgets' array
    #
    def initialize(widgets)
      if (widgets.is_a? Hash)
        @wdescr = widgets
        @wopts = @wdescr[:wopts] || {}
        puts ">>>> #{widgets.inspect}"
        widgets = @wopts[:widgets] || []
      end
      @widgets = widgets.collect {|w| OMF::Web::Widget::AbstractWidget.create_widget(w) }
      @active_index = 0
      @active_widget = @widgets[0]
    end

    def content()
      #widget @active_widget
      widgets = @widgets  
      prefix = "w#{self.object_id}"    
      @widgets.each_with_index do |w, i|
        style = i == @active_index ? '' : 'display:none'
        div :id => "#{prefix}_#{i}", :class => prefix, :style => style do
          widget(w)
        end
      end 
    end

    def collect_data_sources(ds_set)
      @active_widget.collect_data_sources(ds_set)
    end
    
    def name
      @active_widget.name
    end
    
    # Return html for an optional widget tools menu to be added
    # to the widget decoration by the theme.
    # 
    def tools_menu()
      widgets = @widgets
      active_index = @active_index
      wp = "w#{self.object_id}"
      Erector.inline do
        ol :class => :widget_tools_menu do
          widgets.each_with_index do |w, i|
            is_active = (i == active_index)
            lopts = {}
            lopts[:class] = "#{w.widget_type}#{is_active ? ' current' : ''}"
            lopts[:id] = "#{wp}_l_#{i}"
            li lopts do
              a :href => "javascript:OML.show_widget('#{wp}', #{i}, '#{w.base_id}');"  do
                span w.name, :class => :widget_tools_menu
              end
            end
          end
          li :class => 'info' do
            a :href => "javascript:OML.show_info('#{wp});"  do
              span 'Info' , :class => :widget_tools_menu
            end
          end
          
        end
      end.to_html
    end    



  end # StackedWidget

end
