
require 'coderay'
require 'omf-web/theme/abstract_page'

module OMF::Web::Theme

  class CodeRenderer < Erector::Widget
    
    depends_on :css, "/resource/css/coderay.css"
    
    def initialize(widget, content, opts)
      super opts
      @content = content
    end
        
    def content()
      link :href => "/resource/css/coderay.css", 
        :media => "all", :rel => "stylesheet", :type => "text/css"     
      div :class => "oml_code CodeRay" do
        rawtext(@content.html :line_numbers => :inline, :tab_width => 2, :wrap => :div)
      end
    end
    
  end
  
end
