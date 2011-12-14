# This experiment can be used to power on, off, reset or reboot nodes using the CMC

# empty group to stop OMF from complaining
# & prevent it from powering on nodes
defGroup("tell","")

defProperty('nodes', 'system:topo:all', 'Nodes to act on')
defProperty('command', false, 'Command as in on, offh, offs, reboot, reset')

topo = nil
begin
  # if 'nodes' is a topology file, try to load it
  topo = Topology["#{prop.nodes}"]
rescue
  # if not create a new topology here
  topo = Topology.create(nil, "#{prop.nodes}")
end

tuples = []
call = nil

case "#{prop.command}"
when "on"
  call = "on"
when "offh"
  call = "offHard"
when "offs"
  call = "offSoft"
when "reboot"
  call = "reboot"
when "reset"
  call = "reset"
else
  raise "Unknown command: '#{prop.command}'. Use 'help' to see usage information."
end

$stderr.print " Talking to the CMC service, please wait"

topo.eachNode {|n|
  tuples << ["#{n.to_s}", eval("OMF::Services.cmc.#{call}"+
    "(n.to_s, OConfig.domain).elements[1].name")]
  $stderr.print "."
}

puts
puts "-----------------------------------------------"
puts " Domain: #{OConfig.domain} - Command: #{call}"
tuples.each {|t|
  puts " Node: #{t[0]}   \t Reply: #{t[1]}"
}
puts "-----------------------------------------------"

Experiment.done
