
#==============================================================================#
# sample6.rb
# $Id: sample6.rb,v 1.6 2002/11/19 10:15:34 rcn Exp $
#==============================================================================#

require 'svg2'

svg = SVG2.new(:width => '4in', :height => '4in', :view_box => '0 0 400 400') { |s|

  s.group(:fill => 'none', :stroke => '#CCCCCC', :stroke_width => 1) { |g|
    20.step(380, 20) { |i|
      g.line(:x1 => 20, :y1 => i, :x2 => 380, :y2 => i)
      g.line(:from => [i, 20], :to => [i, 380])
    }
  }
  s.group(:fill => 'none', :stroke => '#333333', :stroke_width => 2) { |g|
    g.line(:from => [20, 20], :to => [20, 380])
    g.line(:from => [20, 380], :to => [380, 380])
  }

  s.polyline(:fill => 'none', :stroke => '#CC0000', :stroke_width => 3, :stroke_opacity => 0.6) { |p|
    (0..18).each { |i| p.point(i * 20 + 20, 380 - i ** 2) }
  }
  s.polyline(:fill => 'none', :stroke => '#009900', :stroke_width => 3, :stroke_opacity => 0.6) { |p|
    (0..18).each { |i| p.point(i * 20 + 20, 380 - i * 10) }
  }
  s.polyline(:fill => 'none', :stroke => '#0000CC', :stroke_width => 3, :stroke_opacity => 0.6) { |p|
    (0..18).each { |i| p.point(i * 20 + 20, 380 - (Math.sin(i.to_f / 10) * 300).to_i) }
  }
}

print svg.to_s

