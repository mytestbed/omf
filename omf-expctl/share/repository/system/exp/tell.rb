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
nodeSet = topo.eachNode {|n| n.to_s}.join(",")
begin
  result = eval("OMF::Services.cmc.#{call}(:set=>nodeSet, :domain=>OConfig.domain)")
  puts
  puts "-----------------------------------------------"
  puts " Domain: #{OConfig.domain} - Command: #{call}"
  result.elements.each("#{call.upcase}/detail/#{call.upcase}") {|e|
    reply = e.elements[1].name
    if reply == "ERROR"
      reply = reply + "(#{e.elements[1].get_text()})"
    end
    puts " Node: #{e.attributes['name']}   \t Reply: #{reply}"
  }
  puts "-----------------------------------------------"
rescue Exception => ex
  puts " Failed to execute #{call} command: #{ex}"
end

Experiment.done
