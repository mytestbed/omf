# OMF_VERSIONS = 6.0
#
# :num_of_garage can be passed in from EC command line
defProperty('num_of_garage', 1, 'Number of garage to start')

garages = (1..prop.num_of_garage).map { |i| "garage_#{i}" }

defEvent :all_engines_up do |state|
  # state holds list of resources, and automatically updated once OMF inform messages received.
  state.find_all do |v|
    v[:type] == 'engine'
  end.size >= prop.num_of_garage
end

defEvent :rpm_reached do |state|
  state.find_all do |v|
    v[:type] == 'engine' && v[:rpm] && v[:rpm] >= 4000
  end.size >= prop.num_of_garage
end

# Define a group and add garages to it.
defGroup('many_garages', *garages)

# :ALL_UP is a pre-defined event,
# triggered when all resources set to be part of groups are available and configured as members of the associated groups.
onEvent :ALL_UP do
  group('many_garages') do |g|
    g.create_resource('primary_engine', type: 'engine', sn: "<%= rand(1000) %>")

    onEvent :all_engines_up do
      info "Accelerating all engines"
      g.resources[type: 'engine'][name: 'primary_engine'].throttle = 40

      g.resources[type: 'engine'][name: 'primary_engine'].sn

      g.resources[type: 'engine'][name: 'primary_engine'].failure
    end

    onEvent :rpm_reached do
      info "All engines RPM reached 4000"
      info "Release All engines throttle"
      g.resources[type: 'engine'].throttle = 0

      after 7.seconds do
        info "Shutting ALL engines off"
        g.resources[type: 'engine'].release

        Experiment.done
      end
    end
  end
end
