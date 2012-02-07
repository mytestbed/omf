
require 'omf-web/widget/abstract_widget'
require 'coderay'
#require 'ftools'

module OMF::Web::Widget::Code
  
  # Maintains the context for a particular code rendering within a specific session.
  #
  class CodeWidget < OMF::Web::Widget::AbstractWidget
    
    depends_on :css, "/resource/css/coderay.css"
    
    attr_reader :name, :opts
    
    def initialize(opts)
      super opts
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
      content = file_content
      type = code_type
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
    
    def file_content()
      ## HACK!!!!
      path = @opts[:file]
      if File.readable?(path)
        File.new(path).read
      else
        "Can't find #{path}"
      end
    end
    
    # Return the language the code is written in 
    #
    def code_type()
      path = @opts[:file]
      if path.end_with? '.rb'
        :ruby
      elsif path.end_with? '.xml'
        :xml
      else
        :text
      end
    end
    
    
  end # CodeWidget
  
end
