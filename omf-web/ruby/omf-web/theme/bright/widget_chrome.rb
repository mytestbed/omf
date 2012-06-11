require 'omf-web/theme/abstract_page'

module OMF::Web::Theme
  class WidgetChrome < Erector::Widget
    
    def initialize(widget, inside_component, opts)
      super opts
      @widget = widget
      @inside_component = inside_component
      @opts = opts
    end    
    
    def render_card_body
      rawtext @widget.content.to_html
    end
    
    def content
      render_widget(@widget)
    end
    
    def render_widget(widget)
      div :class => :widget_container do
        render_widget_header(widget)
        render_widget_info(widget)
        render_widget_body(widget)
        render_widget_footer(widget)        
      end
    end

    def render_widget_header(widget)
      div :class => :widget_header do
        span widget.name, :class => :widget_title
        render_tools_menu
      end
    end

    def render_tools_menu
      menu = @opts[:menu] || {}
      span :class => 'widget_tools_menu', :style => 'float:right' do 
        ol :class => :widget_tools_menu do
          menu.each do |m|
            lopts = {}
            lopts[:class] = "#{m[:class]}#{m[:is_active] ? ' current' : ''}"
            lopts[:id] = m[:id]
            li lopts do
              a :id => "#{m[:id]}_a", :href => "#"  do
                span m[:name] || '???', :class => :widget_tools_menu
              end
            end
          end
          li :class => 'info' do
            a :id => "w#{object_id}_info_a", :href => "#"  do
              span 'Info' , :class => :widget_tools_menu
            end
          end 
        end         
      end
      js = menu.map do |m| 
        %{
          $('\##{m[:id]}_a').click(function(){
            #{m[:js_function]}(#{m.to_json});
          });
        } 
      end
      javascript js.join("\n")
    end

    def render_widget_info(widget)
      if widget_info = widget.widget_info
        wp = "w#{object_id}"
        div :id => "#{wp}_info", :class => 'widget_info', :style => 'display:none' do
          text widget_info
        end  
        javascript %{
          $('\##{wp}_info_a').click(function(){
            $('\##{wp}_info').slideToggle("slow");
          });
        }
      end
    end

    def render_widget_body(widget_inst)
      id = "b#{widget_inst.widget_id}"
      div :class => :widget_body, :id => id do
        rawtext @inside_component.to_html
      end
    end

    def render_widget_footer(widget)
      # NOTHING
    end    

  end # class widget
end # OMF::Web::Theme