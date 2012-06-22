
require 'omf-web/widget/abstract_widget'
require 'coderay'
#require 'ftools'

module OMF::Web::Widget
  
  # Maintains the context for a particular code rendering within a specific session.
  #
  class CodeWidget < AbstractWidget
    
    def self.create_code_widget(type, wdescr)
      return self.new(wdescr)
    end
    
    def initialize(opts)
      super opts
      unless (source = opts[:source])
        raise "Missing 'source' option in '#{opts.describe}'"
      end      
      @content = render_code(source)
    end
        
    def content()
      OMF::Web::Theme.require 'code_renderer'
      OMF::Web::Theme::CodeRenderer.new(self, @content, @opts)
    end
    
    def collect_data_sources(ds_set)
      ds_set
    end
    
  
    @@codeType2mime = {
      :ruby => '/text/ruby',
      :xml => '/text/xml'
    }
    
    def render_code(source)
      content = load_content(source)
      type = code_type(source)
      mimeType = @@codeType2mime[type]
      
      begin
        CodeRay.scan content, type
        #tokens.html :line_numbers => :inline, :tab_width => 2, :wrap => :div
      rescue Exception => ex
        puts ">>>> ERORRO: #{ex} #{ex.backtrace}"
      end
    end
    
    def load_content(source)
      unless File.readable?(source)
        raise "Cannot read text file '#{source}'"
      end
      content = File.open(source).read
    end
        
    # Return the language the code is written in 
    #
    def code_type(source)
      if source.end_with? '.rb'
        :ruby
      elsif source.end_with? '.xml'
        :xml
      else
        :text
      end
    end
    
    
  end # CodeWidget
  
end
