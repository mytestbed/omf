defProperty('radius', 8, "Circle radius")
defProperty('xCenter', 10, "x coordinate of circle center")
defProperty('yCenter', 10, "y coordinate of circle center")

# nodes arranged in a circle
defTopology('system:topo:circle') { |t|
  puts "<#{t}>"
  # use simple 4-way algorithm
  radius = prop.radius.value
  xCenter = prop.xCenter.value
  yCenter = prop.yCenter.value

  r2 = radius * radius
  t.addNode(xCenter, yCenter + radius)
  t.addNode(xCenter, yCenter - radius)
  (1..radius).each { |x|
    y = (Math.sqrt(r2 - x*x) + 0.5).to_i
    t.addNode(xCenter + x, yCenter + y)
    t.addNode(xCenter + x, yCenter - y)
    t.addNode(xCenter - x, yCenter + y)
    t.addNode(xCenter - x, yCenter - y)
  }
}
