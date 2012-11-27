# This experiment prints the CMC power state of each node in the given topology

# empty group to stop OMF from complaining
# & prevent it from powering on nodes
defGroup("stat","")

defProperty('nodes', 'system:topo:all', 'Nodes to query')
defProperty('summary', false, 'Show a summary instead of details')

topo = nil
begin
  # if 'nodes' is a topology file, try to load it
  topo = Topology["#{prop.nodes}"]
rescue
  # if not create a new topology here
  topo = Topology.create(nil, "#{prop.nodes}")
end

tuples = []

$stderr.print " Talking to the CMC service, please wait"

topo.eachNode {|n|
  tuples << ["#{n.to_s}", "#{OMF::Services.cmc.status(n.to_s, OConfig.domain).
    first_element("NODE_STATUS/detail/node").attributes['state']}"]
  $stderr.print "."
}

puts
puts "-----------------------------------------------"
puts " Domain: #{OConfig.domain}"
if property.summary.value
  on = off = unknown = 0
  tuples.each {|t|
    on += 1 if t[1] == "POWERON"
    off += 1 if t[1] == "POWEROFF"
    unknown += 1 if t[1] == "UNKNOWN"
  }
  puts " Number of nodes in 'Power ON' state:\t#{on}"
  puts " Number of nodes in 'Power OFF' state:\t#{off}"
  puts " Number of nodes in 'Unknown' state:\t#{unknown}"
else
  tuples.each {|t|
    puts " Node: #{t[0]}   \t State: #{t[1]}"
  }
end
puts "-----------------------------------------------"

Experiment.done
