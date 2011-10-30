
require 'omf-web/widget/abstract_widget'
require 'coderay'
#require 'ftools'

module OMF::Web::Widget::Code
  
  # Maintains the context for a particular code rendering within a specific session.
  #
  class CodeWidget < OMF::Web::Widget::AbstractWidget
    
    depends_on :css, "/resource/css/coderay.css"
    
    attr_reader :name, :opts
    
    def initialize(description)
      super description.opts

      @description = description 
      @name = description.name
    end
        
    def content()
      div :id => @base_id, :class => "oml_code CodeRay" do
        rawtext render_code
      end
    end
    
  
    @@codeType2mime = {
      :ruby => '/text/ruby',
      :xml => '/text/xml'
    }
    
    def render_code()
      content = @description.content
      type = @description.code_type
      mimeType = @@codeType2mime[type]
      
      #puts ">>>>RENDER_CODE>> #{content.length}"
      begin
        tokens = CodeRay.scan content, type
        tokens.html :line_numbers => :inline, :tab_width => 2, :wrap => :div
      rescue Exception => ex
        puts ">>>> ERORRO: #{ex} #{ex.backtrace}"
      end
      #puts "<<<<< END OF RENDER CODE #{tokens.inspect}"
    end
    
        
  end # CodeWidget
  
end
