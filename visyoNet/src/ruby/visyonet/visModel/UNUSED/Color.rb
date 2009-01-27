
module VisyoNet
  class Color
    attr_accessor :r, :g, :b
    
    def initialize(r, g, b)
      @r = r
      @g = g
      @b = b
    end
    
    def setRGB(r, g, b)
      @r = r
      @g = g
      @b = b
    end
    
    #make an xml representation for color in r, g and b
    def xmlAttr(array = nil)
      #return " r=\"" + r.to_s + "\" g=\"" + g.to_s + "\" b=\"" + b.to_s + "\""
      a = array || Array.new
      a << ['r', @r]
      a << ['g', @g]
      a << ['b', @b]
      a
    end
  end # class
end # module
