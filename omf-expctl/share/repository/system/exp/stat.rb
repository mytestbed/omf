# empty group to stop OMF from complaining
# & prevent it from powering on nodes
defGroup("stat","")

defProperty('nodes', 'system:topo:all', 'Nodes to query')
defProperty('summary', false, 'Show a summary instead of details')

topo = nil
begin
  topo = Topology["#{prop.nodes}"]
rescue
  defTopology("topo") {|t|
    prop.nodes.value.split(',').each {|n|
      t.addNode(n)
    }
  }
  topo = Topology['topo']
end

tuples = []
 
topo.eachNode {|n|
  tuples << ["#{n.to_s}", "#{OMF::Services.cmc.status(n.to_s, OConfig.domain).first_element("NODE_STATUS/detail/node").attributes['state']}"]
}

puts "-----------------------------------------------"
puts " Domain : #{OConfig.domain}"
if property.summary.value
  on = off = unknown = 0
  tuples.each {|t|
    on += 1 if t[1] == "POWERON"
    off += 1 if t[1] == "POWEROFF"
    unknown += 1 if t[1] == "UNKNOWN"
  }
  puts " Number of nodes in 'Power ON' state      : #{on}"
  puts " Number of nodes in 'Power OFF' state     : #{off}"
  puts " Number of nodes in 'Unknown' state : #{unknown}"
else
  tuples.each {|t|
    puts " Node #{t[0]}   \t State: #{t[1]}"
  }
end
puts "-----------------------------------------------"

Experiment.done
