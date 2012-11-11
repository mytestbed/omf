# OMF_VERSIONS = 6.0
#
defProperty('num_of_garage', 1, 'Number of garage to start')

garages = (1..prop.num_of_garage).map { |i| "garage_#{i}" }

defGroup(exp.id) do |g|
  g.add_resource(*garages)
end

defEvent :all_garages_up do
  exp.state.find_all { |v| v[:hrn] =~ /garage_.+/ }.size >= exp.property.num_of_garage
end

defEvent :all_engines_up do
  exp.state.find_all { |v| v[:type] == 'engine' }.size >= exp.property.num_of_garage
end

defEvent :rpm_reached do
  exp.state.find_all do |v|
    v[:type] == 'engine' &&
      v[:rpm] && v[:rpm] >= 4000
  end.size >= prop.num_of_garage
end

defEvent :all_off do
  exp.state.find_all do |v|
    v[:released]
  end.size >= prop.num_of_garage
end

onEvent :all_off do
  info "All done!"
  Experiment.done
end

onEvent :rpm_reached do
  allGroups do |g|
    info "All engines RPM reached 4000"
    info "Release All engines throttle"
    g.resources[type: 'engine'].throttle = 0

    after 7.seconds do
      info "Shutting ALL engines off"
      g.resources[type: 'engine'].release
    end
  end
end

onEvent :all_garages_up do
  allGroups do |g|
    g.create_resource('primary_engine', type: 'engine')
  end
end

onEvent :all_engines_up do
  info "Accelerating all engines"
  allGroups do |g|
    g.resources[type: 'engine'][name: 'primary_engine'].throttle = 40
  end
end
