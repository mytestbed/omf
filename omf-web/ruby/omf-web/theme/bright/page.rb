require 'omf-web/theme/abstract_page'

module OMF::Web::Theme
  class Page < OMF::Web::Theme::AbstractPage
    
    depends_on :css, '/resource/css/theme/bright/reset-fonts-grids.css'
    depends_on :css, "/resource/css/theme/bright/bright.css"
   
    depends_on :script, %{
      OML.show_widget = function(opts) {
        var prefix = opts.inner_class;
        var index = opts.index;
        var widget_id = opts.widget_id;
        
        $('.' + prefix).hide();
        $('#' + prefix + '_' + index).show();
        
        var current = $('#' + prefix + '_l_' + index);
        current.addClass('current');
        current.siblings().removeClass('current');
         
        OML.widgets[widget_id].resize().update();
      };
    }
       
    # def initialize(widget, opts)
      # super
    # end
 
    def content
      div :id => 'doc3' do
        div :id => 'hd' do
          render_top_line
          h1 @page_title || 'Missing :page_title' 
        end
        div :id => 'bd' do
          render_body
        end
        div :id => 'ft' do
          render_footer
        end
      end
    end
    
    def render_top_line
      div :id => :top_line do
        render_tab_menu
        render_tools_menu
      end
    end
        
    # def render_tabs
      # div :id => 'tabs' do
        # ul :id => 'mainTabs' do
          # @tabs.each do |h|
            # li do
              # opts = {:href => "/#{h[:id]}/show?sid=#{Thread.current["sessionID"]}"}
              # opts[:class] = 'current' if h[:id] == @active_id
              # a h[:name], opts
            # end
          # end
        # end
      # end
    # end
            
    def render_tab_menu
      ol :id => :tab_menu do
        @tabs.each do |h|
          lopts = h[:id] == @tab ? {:class => :current} : {}
          li lopts do 
            a :href => "#{@prefix}/#{h[:id]}?sid=#{Thread.current["sessionID"]}" do
              span h[:name], :class => :tab_text
            end
          end
        end
      end
    end
            
    # def render_tab_menu2
      # ol :id => :tab_menu do
        # [:first, :second].each do |n|
          # opts = n == :second ? {:class => :selected} : {}
          # li opts do 
            # a :href => n do
              # span n, :class => :tab_text
            # end
          # end
        # end
      # end
    # end

    def render_tools_menu
      div :id => :tools_menu do
        a 'Log in', :href => '/login'
      end
    end
    
    def render_body
      render_flash
      render_card_body
    end
    
    def render_card_body
      return unless @widget
      Thread.current["top_renderer"] = self
      rawtext @widget.content.to_html
    end
    
    
    # def render_widget(widget)
      # div :class => :widget_container do
        # render_widget_header(widget)
        # render_widget_info(widget)
        # render_widget_body(widget)
        # render_widget_footer(widget)        
      # end
    # end
# 
    # def render_widget_header(widget)
      # div :class => :widget_header do
        # span widget.name, :class => :widget_title
        # if tools_menu = widget.tools_menu
          # span :class => 'widget_tools_menu', :style => 'float:right' do 
            # rawtext tools_menu
          # end
        # end
      # end
    # end
# 
    # def render_widget_info(widget)
      # if widget_info = widget.widget_info
        # wp = "w#{widget.object_id}"
        # div :id => "#{wp}_info", :class => 'widget_info', :style => 'display:none' do
          # text widget_info
        # end  
        # javascript %{
          # $('\##{wp}_info_a').click(function(){
            # $('\##{wp}_info').slideToggle("slow");
          # });
        # }
      # end
    # end
# 
    # def render_widget_body(widget_inst)
      # id = "b#{widget_inst.widget_id}"
      # div :class => :widget_body, :id => id do
        # widget widget_inst
      # end
      # javascript %{
        # var aa = $("\##{id}");
        # $("\##{id}").resize(function() {
          # $.doTimeout('resize', 250, function() {
            # var i;
          # });
        # });
       # }
    # end
# 
    # def render_widget_footer(widget)
      # # NOTHING
    # end

    
    def render_footer
      span :style => 'float:right;margin-right:10pt' do
        text @footer_right || OMF::Web::VERSION
      end
      ##                   image_tag 'logo-bottom.gif', {:align => 'right', :style => 'margin-right:10pt
      text @footer_left || 'Brought to you by the TEMPO Team'
    end
    

  

  end # class Page
end # OMF::Web::Theme