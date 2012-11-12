#
# Test 1
#
# Testing one node in one group running one exec command for an already installed app
#
defProperty('res1', "unconfigured-node-1", "ID of a node")
defProperty('res2', "unconfigured-node-2", "ID of a node")

defGroup('Actor', property.res1, property.res2)

defEvent(:ALL_UP) do
  exp.state.size >= 2
end

onEvent(:ALL_UP) do |event|
  wait 3
  info "TEST - allGroups"
  group("Actor").exec("/bin/date")

  wait 3.seconds
  info "TEST - group"
  group("Actor").exec("/bin/hostname")

  wait 3.seconds
  group("Actor") do |g|
    g.resources[type: 'application'].release
  end

  after 3.seconds do
    Experiment.done
  end
end
