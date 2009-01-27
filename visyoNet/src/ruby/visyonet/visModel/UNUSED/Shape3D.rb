#
# 3D shapes
#

class Shape3D < Shape
  attr_reader :width, :height, :depth
  
  def initialize(layer = nil, id = nil)
    super(layer, id)
    @width = 0
    @height = 0
    @depth = 0
  end
  
#  def to_XML()
#    return "<shape3D/>"
#  end
  
  # Return the object attributes as an array
  def xmlAttr()
    a = super()
    a << ['width', @width]
    a << ['height', @height]
    a << ['depth', @depth]
    @fillColor.xmlAttr.each { |ac|
      a << ac
    }
    a
  end  
  
  def xmlType
    return 'shape3D'
  end
  
end


# circle
class Cylinder < Shape3D
  attr_accessor :radius, :height, :fillColor
  
  def initialize(radius = 0, height = 0, fillColor = nil)
    super()
    @radius = radius
    @height = height
    
    @width= radius * 2
    @depth = radius * 2
    
    @fillColor = fillColor
  end
  
  def to_XML()
    return "<shape type=\"cylinder\" id=\"" + @displayid.to_s + "\" x=\"" + @position.x.to_s + "\" y=\"" + @position.y.to_s + 
            "\" radius=\"" + @radius.to_s + "\" height=\"" + ("%.2f" % @height.to_s) + "\"" + @fillColor.to_XML() + " a=\"" + @alpha.to_s + "\"/>"
  end
  
end

# 3D arrow
class Arrow3D < Shape3D
  attr_accessor :from, :to, :thickness, :color
  
  def initialize(from = nil, to = nil, height = 0, thickness = 0, color = nil)
    @from = from
    @to = to
    @thickness = thickness
    @color = color
    @height = height
    
  end
end
