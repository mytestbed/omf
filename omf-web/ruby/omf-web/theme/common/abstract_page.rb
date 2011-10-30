require 'erector'

module OMF::Web::Theme
  class AbstractPage < Erector::Widget
    
    
    depends_on :js, '/resource/js/jquery.js'
    depends_on :js, '/resource/js/stacktrace.js'
    depends_on :js, "/resource/js/require3.js"
  
    depends_on :script, %{
      L.baseURL = "/resource";
      if (typeof(OML) == "undefined") { OML = {}; }
    }
    
    def initialize(opts = {})
      super opts
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
  end # class AbstractPage
end # OMF::Web::Theme
  