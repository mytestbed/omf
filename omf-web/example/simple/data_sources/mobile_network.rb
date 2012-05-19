



require 'omf-oml/network'
require 'omf-oml/table'

include OMF::OML
  
nw = OmlNetwork.new 'mobile_network'
nw.node_schema [[:x, :float], [:y, :float], [:capacity, :float]]
nw.create_node :n0, :x => 0.2, :y => 0.2, :capacity =>  0.3
nw.create_node :n1, :x => 0.8, :y => 0.2, :capacity =>  0.5
nw.create_node :n2, :x => 0.8, :y => 0.8, :capacity =>  0.8
nw.create_node :n3, :x => 0.2, :y => 0.8, :capacity =>  0.8
nw.create_node :m1, :x => 0.5, :y => 0.7, :capacity =>  0.8

nw.link_schema [[:load, :float]]
nw.create_link :l01, :n0, :m1, :load => 0.8

require 'omf_web'
OMF::Web.register_datasource nw, :index => :id

# Move mobile node
Thread.new do
  begin
    angle = 0
    delta = Math::PI / 6
    twoPi = 2 * Math::PI
    r = 0.25
    loop do
      sleep 1
      angle += delta
      angle -= twoPi if angle >= twoPi
      nw.transaction do 
        m = nw.node(:m1)
        m[:x] = r * Math.sin(angle) + 0.5
        m[:y] = r * Math.cos(angle) + 0.5
      #puts m.describe
        
      end
    end
  rescue Exception => ex
    puts ex
    puts ex.backtrace.join("\n")
  end
end


