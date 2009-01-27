
include VisyoNet
puts ">>>>>"

VisMapping::defMappingGroup('vis1') { |mg|

  mg.width = mg.height = '14 cm'
  mg.boundingBox = '0 0 140 140'
  mg.transform = 'translate(20,20)'
  
  mg.defMapping('node') { |canvas, anchor, node|
    #anchor = node[:anchor] = Position.new(node[:x], node[:y])
    #layer = canvas[:node]
    #create a circle for a node
    color = 'gray'
    case node[:status]
    when 0 
      color = 'red'
    when 1
      color = 'green'
    end
    x = 10 * node[:x].to_i
    y = 10 * node[:y].to_i
    circle = SVG::Circle.new(x, y, 4) {
      self.style = SVG::Style.new(:fill => color)
    }
    canvas << circle
    
    textStyle = SVG::Style.new(
#        :fill => '#FFFFFF',
        :font_size => 2,
        :size => 2,        
        :font_family => 'serif',
        :baseline_shift => 'sub',
        :text_anchor => 'middle'
      )
    
    canvas << SVG::Text.new(x, y, "#{node[:x]}@#{node[:y]}") {
      self.style = SVG::Style.new(
#        :fill => '#FFFFFF',
        :font_size => 2,
        :size => 2,        
        :font_family => 'serif',
        :baseline_shift => 'sub',
        :text_anchor => 'middle'
      )
    }
#    circle.labelText = "#{node[:x]}@#{node[:y]}"
    #depending on this value of status set the color
#    case node[:status]
#    when 0 
#      circle.fillColor = Color.new(255,0,0) #set this color to red
#    when 1
#      circle.fillColor = Color.new(0,255,0) #set this color to green
#    else
#      circle.fillColor = Color.new(20,20,20) #set this color to gray 
#    end
  }
  
  mg.defMapping('link') { |canvas, anchor, link|
    #create an arrow
#    layer = canvas[:layer]
#    arrow = Arrow2D.new(layer, link.id)
#    arrow.from = link.fromNode[:anchor]
#    arrow.to = link.toNode[:anchor]
#    # a better solution would be aware of the shapes 
#    #arrow.from = canvas[link.from.id]
#    #arrow.to = canvas[link.to.id]
#    
#    if (rate = link[:rate])
#      arrow.labelText = "rate"
#      arrow.thickness = 1.0 * rate / 50 * 10.0 
#      arrow.color = Color.new(0,0,0)
#    else
#      # no rate, grey arrow with thicknes 1
#      arrow.thickness = 1 
#      arrow.color = Color.new(131,131,131) # grey
#    end
  }
}
