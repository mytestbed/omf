
include VisyoNet

VisMapping::defMappingGroup('vis1', 10, 10) { |mg|
  mg.defMapping('node') { |canvas, anchor, node|
    anchor = node[:anchor] = Position.new(node[:x], node[:y])
    layer = canvas[:node]
    #create a circle for a node
    circle = Circle.new(layer, node.id); 
    circle.radius = 0.8 #set the radius of this circle
    circle.position = anchor
    circle.labelText = "#{node[:x]}@#{node[:y]}"
    #depending on this value of status set the color
    case node[:status]
    when 0 
      circle.fillColor = Color.new(255,0,0) #set this color to red
    when 1
      circle.fillColor = Color.new(0,255,0) #set this color to green
    else
      circle.fillColor = Color.new(20,20,20) #set this color to gray 
    end
    
    # loadIn
    cIn = Cylinder.new(layer, "#{node.id}.loadIn")
    cIn.labelText = "loadIn"
    cIn.radius = 0.5
    cIn.height =  node[:loadIn].to_i / 90.00 * 2.00
    cIn.fillColor = Color.new(124,0,249)
    cIn.position = anchor.translate(-0.25, 0)
    
    # loadOut
    cOut = Cylinder.new(layer, "#{node.id}.loadOut")
    cOut.labelText = "loadOut"
    cOut.radius = 0.5
    cOut.height =  node[:loadOut].to_i / 90.00 * 2.00
    cOut.fillColor = Color.new(255,111,40)
    cOut.position = anchor.translate(0.25, 0)
  }
  
  mg.defMapping('link') { |canvas, anchor, link|
    #create an arrow
    layer = canvas[:layer]
    arrow = Arrow2D.new(layer, link.id)
    arrow.from = link.fromNode[:anchor]
    arrow.to = link.toNode[:anchor]
    # a better solution would be aware of the shapes 
    #arrow.from = canvas[link.from.id]
    #arrow.to = canvas[link.to.id]
    
    if (rate = link[:rate])
      arrow.labelText = "rate"
      arrow.thickness = 1.0 * rate / 50 * 10.0 
      arrow.color = Color.new(0,0,0)
    else
      # no rate, grey arrow with thicknes 1
      arrow.thickness = 1 
      arrow.color = Color.new(131,131,131) # grey
    end
  }
}
