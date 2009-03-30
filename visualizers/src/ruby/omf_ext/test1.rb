if __FILE__ == $0
  # TODO Generated stub

  require 'rubygems'
  require 'markaby'
  
  class Foo
    def self.javascript_include_tag(name)
      "JS_INCLUDE(#{name})"
    end
    
    def self.stylesheet_link_tag(name)
      "CSS_INCLUDE(#{name})"
    end
    
    def self.render(name)
      "====RENDER(#{name})===="
    end
    
#    def self.flash(*args)
#      
#    end

    def self.content_for_layout
      
    end
  end
  
  c = File.new("omf_ext/application.mab").read
  t = Markaby::Template.new(c)
  puts "===="
  puts t.render({:params => {}, :flash => {}}, Foo)
  puts "===="
exit

  mab = Markaby::Builder.new({:params => {}, :flash => {}}, Foo)
  mab do
    load 'application.mab'
  end
  mab.html do
      head do
        meta 'http-equiv' => "content-type", :content => "text/html;charset=UTF-8"
        #title "Publication: #{controller.action_name.capitalize}"
        javascript_include_tag :defaults
        javascript_include_tag 'lightbox'
    
        if (extra_includes = @helpers.instance_variable_get('@javascript_includes'))
          extra_includes.each do |js|
            javascript_include_tag js
          end
        end
        
        stylesheet_link_tag 'lightbox'
        stylesheet_link_tag 'screen'
        stylesheet_link_tag 'welcome'
        self << '<!--[if IE]>'
          stylesheet_link_tag 'ie'
        self << '<![endif]-->'
      end
  if params[:action] == 'xxxlogin'
    render :partial => 'shared/login'
  else
    body.publication do
      div.header! do
        h3.top_menu do
#          if User.current.nil?
#            a 'Log in', :href => "/welcome/login", :title => "Log-in into the system to administer own records"
#          else
#            text "Logged in as #{User.current.name}"
            text "Logged in as max"
            text ' ('
            a 'Log out', :href => "/welcome/logout", :title => "Log-out and clear the cookie off your machine"
            text ')'
#            text ' | '
#          end
#          a 'Help', :href => "/help", :target => "_blank"
        end
        
        h1 "Publications"
        
        render :partial => 'shared/tabs'
      end
      
      div.body do
        table.layout do
          tbody do
            tr do
              td.left do
                div.left do
                  unless flash[:notice].nil? 
                    div.flash_notice.flash flash[:notice]
                  end
                  unless flash[:alert].nil?
                    div.flash_alert.flash do
                      a = flash[:alert]
                      if a.kind_of? Array
                        ul do
                          a.each do |t|
                            li t
                          end
                        end
                      else
                        text a
                      end
                    end
                  end
                  
                  div.col do
                    render :partial => 'shared/announcement'
                    self << content_for_layout #yield 
                  end
                  div.bottom do
                    self << '&nbsp;'
                  end
                  div.footer! do
                    span('200809280', :style => 'float:right;margin-right:10pt')
 ##                   image_tag 'logo-bottom.gif', {:align => 'right', :style => 'margin-right:10pt'}
                    text 'Brought to you by the Curious Beetle Rescue Team'
                  end
                end
              end
              td.right do
                div.right do
                  div.col do
    #                    div.right_announce do
    #                      render :partial => 'shared/feedback'
    #                      render :partial => 'shared/right_help'
                      render :partial => 'right_panel'
    #                    end
                  end
                end
              end
              
            end
          end
        end
      end
    end
  end    
    
  end  
  puts mab.to_s

end