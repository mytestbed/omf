#
# Test 1
#
# Testing one node in one group running one exec command for an already installed app
#
defProperty('res1', "unconfigured-node-1", "ID of a node")
defProperty('res2', "unconfigured-node-2", "ID of a node")

defGroup('Actor', property.res1, property.res2)
defGroup('Bob', property.res1, property.res2)

onEvent(:ALL_UP) do
  wait 3
  info "TEST - allGroups"
  allGroups.exec("/bin/date")

  wait 3
  info "TEST - group"
  group("Actor").exec("/bin/hostname -f")

  Experiment.done
end
