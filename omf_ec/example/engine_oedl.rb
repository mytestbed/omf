# OMF_VERSIONS = 6.0
#
defProperty('name', 'garage', 'Name of garage')

garages = [prop.name]

defEvent :engine_created do |state|
  # state holds list of resources, and automatically updated once OMF inform messages received.
  state.find_all do |v|
    v[:type] == 'engine'
  end.size >= 1
end

defEvent :rpm_reached_4000 do |state|
  state.find_all do |v|
    v[:type] == 'engine' && v[:rpm] && v[:rpm] >= 4000
  end.size >= 1
end

# Define a group and add garages to it.
defGroup('garages', *garages)

# :ALL_UP is a pre-defined event,
# triggered when all resources set to be part of groups are available and configured as members of the associated groups.
onEvent :ALL_UP do
  group('garages') do |g|
    g.create_resource('primary_engine', type: 'engine', sn: "<%= rand(1000) %>")

    onEvent :engine_created do
      info ">>> Accelerating all engines"
      g.resources[type: 'engine'][name: 'primary_engine'].throttle = 50

      g.resources[type: 'engine'][name: 'primary_engine'].sn
    end

    onEvent :rpm_reached_4000 do
      info ">>> Engine RPM reached 4000"

      info ">>> Reduce engine throttle"
      g.resources[type: 'engine'].throttle = 0

      after 7.seconds do
        info ">>> Release engines"
        g.resources[type: 'engine'].release

        done!
      end
    end
  end
end
