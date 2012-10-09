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

nodeSet = topo.eachNode {|n| n.to_s}.join(",")
result = eval("OMF::Services.cmc.status(:set=>nodeSet, :domain=>OConfig.domain)")

puts
puts "-----------------------------------------------"
puts " Domain: #{OConfig.domain}"
if property.summary.value
  on = off = unknown = 0
  result.elements.each("NODE_STATUS/detail/node") {|e|
  if e.attributes['state']
    state = e.attributes['state']
  else
    state = e.elements['ERROR'].get_text()
  end
  puts " Node: #{e.attributes['name']}   \t State: #{state}"
    on += 1 if state == "POWERON"
    off += 1 if state == "POWEROFF"
    unknown += 1 if state == "NOT REGISTERED"
}
  puts " Number of nodes in 'Power ON' state:\t#{on}"
  puts " Number of nodes in 'Power OFF' state:\t#{off}"
  puts " Number of nodes in 'Unknown' state:\t#{unknown}"
else
  result.elements.each("NODE_STATUS/detail/node") {|e|
  if e.attributes['state']
    state = e.attributes['state']
  else
    state = e.elements['ERROR'].get_text()
  end
  puts " Node: #{e.attributes['name']}   \t State: #{state}"
}
end

puts "-----------------------------------------------"

Experiment.done
