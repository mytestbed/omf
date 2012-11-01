# OMF_VERSIONS = 6.0
#
defGroup('world') do |g|
  g.add_resource('mclaren')
  g.add_resource('ferrari')
end

defEvent :all_up do
  allEqual(['mclaren', 'ferrari']) do |name|
    exp.state.any? { |v| v[:hrn] == name }
  end
end

defEvent :rpm_reached do
  allEqual(exp.state.find_all { |v| v[:type] == 'engine' }) do |engine|
    engine[:rpm] && engine[:rpm] >= 4000
  end
end

onEvent :rpm_reached do
  group('world') do |g|
    info "All engines RPM reached 4000"
    info "Release All engines throttle"
    g.resources(type: 'engine').throttle = 0

    after 5.seconds do
      info "All done!"
      Experiment.done!
    end
  end
end

onEvent :all_up do
  group('world') do |g|
    g.create_resource('primary_engine', type: 'engine')

    after 2.seconds do
      info "Accelerating all engines"
      g.resources(type: 'engine', name: 'primary_engine').throttle = 50
    end
  end
end
