

module OMF::Web::Widget::Code
  
  class CodeDescription < MObject
    
    attr_reader :name, :opts
    
    #
    # opts:
    #  :file - Name of file to take content from
    #
    def initialize(name, opts = {})
      @name = name
      @opts = opts
    end
        

    # Return content of script
    #
    def content()
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
    
    def create_widget
      require 'omf-web/widget/code/code_widget'
      OMF::Web::Widget::Code::CodeWidget.new(self)
    end

    private

  end # CodeDescription
end # OMF::Web::Widget::Code
