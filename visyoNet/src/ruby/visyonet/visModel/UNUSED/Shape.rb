
#
# shape
#
class Shape
  attr_accessor :id, :isVisible, :labelText, :labelTextColor, :alpha, :position
  
  def initialize(layer = nil, id = nil, visible = true, labelText = "", 
                  labelTextColor = nil, position = nil, alpha = 255)
    @id = id
    @isVisible = visible
    @labelText = labelText
    @labelTextColor = labelTextColor
    @position = position
    @alpha = alpha
    layer << self if layer != nil
  end
  
  def to_XML
    a = xmlAttr
    attr = ''
    a.each {|k, v|
      attr += "#{k}='#{v}' " if v != nil
    }
    return "<shape type='#{xmlType}' #{attr}/>"
  end
    
#  def to_XML()
#    return "<shape/>"
#  end

  # Return the object attributes in XML form
  def xmlAttr
    a = Array.new
    a << ['id', id]
    a << ['isVisible', @visible]
    a << ['labelText', @labelText]
    a << ['labelTextColor', @labelTextColor]
    a << ['x', @position != nil ? @position.x : nil]
    a << ['y', @position != nil ? @position.y : nil]
    a << ['a', @alpha]
  end
  
  def xmlType
    return 'shape'
  end
end
