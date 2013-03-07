# Simple OEDL Experiment for OMF
# displays the hostname and date/time of the remote RC

defProperty('res1', "unconfigured-node-1", "ID of a node")
defGroup('Actor', property.res1)

onEvent(:ALL_UP) do |event|
  after 3 do
    info "TEST - allGroups"
    allGroups.exec("/bin/date")
  end
  after 6 do
    info "TEST - group"
    group("Actor").exec("/bin/hostname -f")
  end
  after 9 do
    Experiment.done
  end
end