# OMF_VERSIONS = 6.0
#
defProperty('num_of_garage', 1, 'Number of garage to start')

garages = (1..prop.num_of_garage).map { |i| "garage_#{i}" }

defEvent :all_engines_up do |state|
  state.find_all do |v|
    v[:type] == 'engine'
  end.size >= prop.num_of_garage
end

defEvent :rpm_reached do |state|
  state.find_all do |v|
    v[:type] == 'engine' &&
      v[:rpm] && v[:rpm] >= 4000
  end.size >= prop.num_of_garage
end

defEvent :all_off do |state|
  state.find_all do |v|
    v[:released]
  end.size >= prop.num_of_garage
end

defGroup(OmfEc.exp.id, *garages) do |g|
  g.create_resource('primary_engine', type: 'engine', sn: "<%= rand(1000) %>")

  onEvent :all_engines_up do
    info "Accelerating all engines"
    g.resources[type: 'engine'][name: 'primary_engine'].throttle = 40

    g.resources[type: 'engine'][name: 'primary_engine'].sn

    g.resources[type: 'engine'][name: 'primary_engine'].failure

    after 1 do
      info OmfEc.exp.state
    end
  end

  onEvent :all_off do
    warn "All done!"
    Experiment.done
  end

  # Define multiple callbacks to same event (last in, first serve)
  onEvent :all_off do
    info "All done!"
  end

  onEvent :rpm_reached do
    info "All engines RPM reached 4000"
    info "Release All engines throttle"
    g.resources[type: 'engine'].throttle = 0

    after 7.seconds do
      info "Shutting ALL engines off"
      g.resources[type: 'engine'].release
    end
  end
end
