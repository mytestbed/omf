require 'omf-web/theme/common/abstract_page'

module OMF::Web::Theme
  class Page < OMF::Web::Theme::AbstractPage
    
    depends_on :css, '/resource/css/theme/bright/reset-fonts-grids.css'
    depends_on :css, "/resource/css/theme/bright/bright.css"
   
    def initialize(opts)
      super opts
    end
 
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
        
    def render_tabs
      div :id => 'tabs' do
        ul :id => 'mainTabs' do
          @tabs.each do |h|
            li do
              opts = {:href => "/#{h[:id]}/show?sid=#{Thread.current["sessionID"]}"}
              opts[:class] = 'current' if h[:id] == @active_id
              a h[:name], opts
            end
          end
        end
      end
    end
            
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
            
    def render_tab_menu2
      ol :id => :tab_menu do
        [:first, :second].each do |n|
          opts = n == :second ? {:class => :selected} : {}
          li opts do 
            a :href => n do
              span n, :class => :tab_text
            end
          end
        end
      end
    end

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
      # Overide
    end
    
    
    def render_widget(widget)
      div :class => :widget_container do
        render_widget_header(widget)
        render_widget_body(widget)
        render_widget_footer(widget)        
      end
    end

    def render_widget_header(widget)
      div :class => :widget_header do
        span widget.name, :class => :widget_title 
      end
    end

    def render_widget_body(widget_inst)
      id = "b#{widget_inst.widget_id}"
      div :class => :widget_body, :id => id do
        widget widget_inst
      end
      javascript %{
        var aa = $("\##{id}");
        $("\##{id}").resize(function() {
          $.doTimeout('resize', 250, function() {
            var i;
          });
        });
       }
    end

    def render_widget_footer(widget)
      # NOTHING
    end

    
    def render_footer
      span :style => 'float:right;margin-right:10pt' do
        text '20111030'
      end
      ##                   image_tag 'logo-bottom.gif', {:align => 'right', :style => 'margin-right:10pt
      text 'Brought to you by the TEMPO Team'
    end

    ############ MAKE SURE WE NEED THE REST    
    
    
    
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
#     
    # def render_card
      # div :class => "card card_#{@active_id}" do
        # div :class => 'card_header' do
          # render_card_actions
          # h1 @card_title || 'Missing :card_title'
        # end
        # render_card_nav
#               
        # if @announcement
          # div :class => 'card_announcement' do 
            # text @announcement
          # end
        # end
#   
        # div :class => 'card_body' do
          # render_card_body
        # end
      # end
    # end
#   
    # def render_card_actions
      # return  # Following is just an example
      # div :class => 'actions' do
        # a 'Action', :class => 'action', :href => '/foo'
      # end
    # end
#     
    # def render_card_nav
      # if @card_nav
        # div :class => 'card_nav' do
          # ul do
            # @card_nav.each do |cn|
              # li :class => cn[:selected] ? 'selected' : nil do
                # a cn[:name] || 'Missing :name', :href => cn[:href] || 'missing/:href'
              # end
            # end
          # end
        # end
      # end
    # end
#       
    # def render_card_body
      # if @body_text
        # p @body_text
      # end
    # end
#     
    # def render_sidebar
      # div :class => 'panel' do
        # h1 'Commands'
#         
        # ul do
          # li do
            # a 'New', :href => 'new', :class => 'action'
          # end
          # li do
            # a 'Update', :href => 'new', :class => 'action'
          # end
        # end
      # end
#       
      # div :class => 'panel help_panel' do
        # h1 'Help'
        # render_help_text
      # end
    # end
#     
    # def render_help_text
      # p do
        # text 'Help is soon coming to a screen near you'
      # end    
    # end
    

  

  end # class Page
end # OMF::Web::Theme