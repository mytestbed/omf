require 'erector'

class Page < Erector::Widget
  
  depends_on :css, "/resource/css/omf_ec.css"
  depends_on :css, '/resource/css/yui-grids-min.css'
  
  depends_on :js, '/resource/js/jquery.js'
  depends_on :js, '/resource/js/stacktrace.js'
  
  # HACK ALERT! THe next two lines shouldn't be here
#  depends_on :js, '/resource/js/jquery.periodicalupdater.js'
  
#  depends_on :css, "coderay.css"
#  depends_on :css, "/css/salsa_picante.css", :media => "print"

#        self << '<!--[if IE]>'
#          stylesheet_link_tag 'ie'
#        self << '<![endif]-->'

  depends_on :js, "/resource/js/require3.js"
  depends_on :script, %{
    L.baseURL = "/resource";
    if (typeof(OML) == "undefined") { OML = {}; }
  }
  
  def initialize(opts = {})
    super opts
  end
  
  def content
    div :id => 'header' do
      div :class => 'top_menu' do
        render_top_menu
      end

      h1 @page_title || 'Missing :page_title'
      render_tabs
    end
    div :class => 'yui3-g', :id => 'page' do
      div :class => 'yui3-u', :id => 'main' do
        render_flash
        render_card
        div :class => 'card_bottom' do # just for cosmetics
          text nbsp
        end
        div :id => :footer do
          render_footer
        end
      end

      div :class => 'yui3-u', :id => 'sidebar' do
        render_sidebar
      end
    end
  end  # content
  
  def render_top_menu
    a 'Log in', :href => '/login'
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
  
  def render_card
    div :class => "card card_#{@active_id}" do
      div :class => 'card_header' do
        render_card_actions
        h1 @card_title || 'Missing :card_title'
      end
      render_card_nav
            
      if @announcement
        div :class => 'card_announcement' do 
          text @announcement
        end
      end

      div :class => 'card_body' do
        render_card_body
      end
    end
  end

  def render_card_actions
    return  # Following is just an example
    div :class => 'actions' do
      a 'Action', :class => 'action', :href => '/foo'
    end
  end
  
  def render_card_nav
    if @card_nav
      div :class => 'card_nav' do
        ul do
          @card_nav.each do |cn|
            li :class => cn[:selected] ? 'selected' : nil do
              a cn[:name] || 'Missing :name', :href => cn[:href] || 'missing/:href'
            end
          end
        end
      end
    end
  end
    
  def render_card_body
    if @body_text
      p @body_text
    end
  end
  
  def render_sidebar
    div :class => 'panel' do
      h1 'Commands'
      
      ul do
        li do
          a 'New', :href => 'new', :class => 'action'
        end
        li do
          a 'Update', :href => 'new', :class => 'action'
        end
      end
    end
    
    div :class => 'panel help_panel' do
      h1 'Help'
      render_help_text
    end
  end
  
  def render_help_text
    p do
      text 'Help is soon coming to a screen near you'
    end    
  end
  
  def render_flash
    return unless @flash
    if @flash[:notice] 
      div :class => 'flash_notice flash' do
        text @flash[:notice]
      end
    end
    if @flash[:alert]
      div :class => 'flash_alert flash' do
        a = @flash[:alert]
        if a.kind_of? Array
          ul do
            a.each do |t| li t end
          end
        else
          text a
        end
      end
    end
  end # render_flesh
  
  def render_footer
    span :style => 'float:right;margin-right:10pt' do
      text '200809280'
    end
    ##                   image_tag 'logo-bottom.gif', {:align => 'right', :style => 'margin-right:10pt
    text 'Brought to you by the TEMPO Team'
  end

  def to_html(opts = {})
    b = super
    e = render_externals
   
    r = Erector.inline do
      instruct
      html do
        head do
          text! e
        end
        body do
          text! b
        end
      end
    end
    r.to_html(opts)  
  end
end # class Page