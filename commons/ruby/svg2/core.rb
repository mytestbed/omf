
#==============================================================================#
# svg/core.rb
# $Id: core.rb,v 1.11 2003/02/06 14:59:43 yuya Exp $
#==============================================================================#

#==============================================================================#
# SVG Module
module SVG2

  def self.new(props, &block)
    return Picture.new(props, &block)
  end


  #============================================================================#
  # DefineStyle Class
  class DefineStyle

    def initialize(class_name, style)
      @class_name = class_name
      @style      = style
    end

    attr_accessor :class_name, :style

    def to_s
      return "#{@class_name} { #{@style} }"
    end

  end # DefineStyle

  #============================================================================#
  # ECMAScript Class
  class ECMAScript

    def initialize(script)
      @script = script
    end

    attr_accessor :script

    def to_s
      text  = %|<script type="text/ecmascript"><![CDATA[\n|
      text << @script << "\n"
      text << %|]]></script>\n|
      return text
    end

  end # ECMAScript

  #============================================================================#
  # ECMAScriptURI Class
  class ECMAScriptURI

    def initialize(uri)
      @uri = uri
    end

    attr_accessor :uri

    def to_s
      return %|<script type="text/ecmascript" xlink:href="#{@uri}" />\n|
    end

  end # ECMAScriptURI

end # SVG

#==============================================================================#
#==============================================================================#
