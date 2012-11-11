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
  after 3.seconds do
    info "TEST - allGroups"
    group("Actor").exec("/bin/date")
  end

  after 6.seconds do
    info "TEST - group"
    group("Actor").exec("/bin/hostname")
  end

  after 9.seconds do
    group("Actor") do |g|
      g.resources[type: 'application'].release
    end

    after 2.seconds do
      Experiment.done
    end
  end
end
