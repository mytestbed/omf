#
# 2D shapes
#
class Shape2D < Shape
  attr_accessor :width, :height
  
  def initialize(layer = nil, id = nil)
    super(layer, id)
    @width = 0
    @height = 0
  end
  
#  def to_XML()
#    return "<shape2D/>"
#  end
  
  # Return the object attributes in XML form
  def xmlAttr()
    a = super()
    a << ['width', @width] if width > 0
    a << ['height', @height] if height > 0
    a
  end  
  
  def xmlType
    return 'shape2D'
  end
end


# circle
class Circle < Shape2D
  attr_accessor :radius, :fillColor
  
  def initialize(layer = nil, id = nil, radius = 0, fillColor = nil)
    super(layer, id)
    @radius = radius
    @width= radius * 2
    @height = radius * 2
    @fillColor = fillColor
  end
  
#  def to_XML()
#    return "<shape type=\"circle\" id=\"" + @displayid.to_s + "\" x=\"" + @position.x.to_s + "\" y=\"" + @position.y.to_s + 
#            "\" radius=\"" + @radius.to_s + "\"" + @fillColor.to_XML() + " a=\"" + @alpha.to_s + "\"/>"
#  end
  

  # Return the object attributes in XML form
  def xmlAttr()
    a = super()
    a << ['radius', @radius]
    @fillColor.xmlAttr(a)
    a
  end  
  
  def xmlType
    return 'circle'
  end
end

# 2D arrow
class Arrow2D < Shape2D
  attr_accessor :from, :to, :thickness, :color
  
  def initialize(layer = nil, id = nil, from = nil, to = nil, 
                  thickness = 1, color = nil)
    super(layer, id)
    @from = from
    @to = to
    @thickness = thickness
    @color = color
  end
  
#  def to_XML()
#    return "<shape type=\"arrow2D\" id=\"" + @displayid.to_s + "\" x1=\"" + @from.x.to_s + "\" y1=\"" + @from.y.to_s + 
#            "\" x2=\"" + @to.x.to_s + "\" y2=\"" + @to.y.to_s + "\" width=\"" + @thickness.to_s + "\"" + @color.to_XML() + " a=\"" + @alpha.to_s + "\"/>"
#  end
  
  # Return the object attributes in XML form
  def xmlAttr
    a = super()
    a << ['thickness', @thickness]
    a << ['x1', @from != nil ? @from.x : nil]
    a << ['y1', @from != nil ? @from.y : nil]
    a << ['x2', @to != nil ? @to.x : nil]
    a << ['y2', @to != nil ? @to.y : nil]
    @color.xmlAttr(a)
  end
  
  def xmlType
    return 'arrow2D'
  end
end
