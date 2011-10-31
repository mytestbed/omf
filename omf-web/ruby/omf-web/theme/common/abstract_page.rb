require 'erector'

module OMF::Web::Theme
  class AbstractPage < Erector::Widget
    
    
    depends_on :js, '/resource/js/jquery.js'
    #depends_on :js, '/resource/js/stacktrace.js'
    depends_on :js, '/resource/js/underscore.js'
    depends_on :js, '/resource/js/backbone.js'    
    depends_on :js, "/resource/js/require3.js"
  
    depends_on :script, %{
      L.baseURL = "/resource";
      OML = {};
        
      var OHUB = {};
      _.extend(OHUB, Backbone.Events);
    }
    
    def initialize(opts)
      super opts
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
  end # class AbstractPage
end # OMF::Web::Theme
  