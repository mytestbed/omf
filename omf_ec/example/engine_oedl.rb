# OMF_VERSIONS = 6.0
#

def_property('garage', 'garage', 'Name of garage')

defEvent :engine_created do |state|
  # state is an array holds list of resources, and automatically updated once OMF inform messages received.
  state.find_all do |v|
    v[:type] == 'engine' && !v[:membership].empty?
  end.size > 0
end

defEvent :rpm_reached_4000 do |state|
  state.find_all do |v|
    v[:type] == 'engine' && v[:rpm] && v[:rpm] >= 4000
  end.size >= 1
end

# Define a group and add garages to it.
defGroup('garages', prop.garage)

# :ALL_UP is a pre-defined event,
# triggered when all resources set to be part of groups are available and configured as members of the associated groups.
onEvent :ALL_UP do
  group('garages') do |g|
    g.create_resource('my_engine', type: 'engine')

    onEvent :engine_created do
      info ">>> Accelerating all engines"
      g.resources[type: 'engine'].throttle = 50

      # We periodically check engine RPM
      every 2.second do
        g.resources[type: 'engine'].rpm
      end
    end

    onEvent :rpm_reached_4000 do
      info ">>> Engine RPM reached 4000"
      info ">>> Reduce engine throttle"
      g.resources[type: 'engine'].throttle = 0
    end

    after 20.seconds do
      info ">>> Release engines"
      g.resources[type: 'engine'].release
      done!
    end
  end
end
