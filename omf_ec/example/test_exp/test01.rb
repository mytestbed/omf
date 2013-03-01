#
# Test 1
#
# Testing one node in one group running one exec command for an already installed app
#
defProperty('res1', "unconfigured-node-1", "ID of a node")

defGroup('Actor', property.res1)

onEvent(:ALL_UP) do
  info "TEST - allGroups"
  allGroups.exec("/bin/date")

  info "TEST - group"
  group("Actor").exec("/bin/hostname -f")

  Experiment.done
end
