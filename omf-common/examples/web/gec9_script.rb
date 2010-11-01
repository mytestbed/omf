
# Define some Properties for this experiment
defProperty('cars', "[1,2,3,4,5,8]", "List of IDs for the mobile resources")
defProperty('cloud', "[1,2,3]", "List of IDs for the cloud resources")
defProperty('resources', "[1,2,3,4,5,8]", "List of IDs for the mobile resources")
defProperty('connected', true, "Connection state of the resource")

# Enable the Support for Disconnection in this Experiment
Experiment.allow_disconnection

# Define the list of all resoures
allMobileResources = property.cars.value.collect do |id| "omf.nypoly.car#{id}" end
allCloudResources = property.cloud.value.collect do |id| "omf.winlab.sb8.node#{id}" end

# Define the Group of Cars
defGroup('Cars', allMobileResouces.join(',')) do |node|
  # Associate a Wimax Monitor application to each car
  node.addApplication("demo:gec9:wimaxmonitor") do |app|
    app.setProperty('interval', 1)
    app.measure('wimax_status', :samples => 1)
  end
  # Associate a GPS Logger application to each car
  node.addApplication("demo:gec9:gpslogger") do |app|
    app.measure('gps_data', :samples => 1)
  end
  # Associate a Sensor Monitor application to each car
  node.addApplication("demo:gec9:sensormonitor") do |app|
    app.setProperty('usb_port', '/dev/ttyUSB1')
    app.measure('sensor_data', :samples => 1)
  end
  # Configure Networking parameters on each car
  node.net.wmax0.ip = "192.168.1.%index%"
end

defGroup('Clouds', allCloudResources.join(',')) do |node|
  node.addApplication("demo:gec9:pnAnalytics")
end

# When all resources have checked-in and all applications are installed on them
# Do the following...
#
onEvent(:ALL_UP_AND_INSTALLED) do |event|
  wait 10
  group('Clouds').startApplications
  wait 10
  group('Cars').startApplications
  wait 10
  # wait 600
  # Experiment.done
end

# Check the Wimax signal every second
# When there is a change in the connection state, fire the 'CONNECTION_CHANGE'
# event, and re-arm so we can continue checking again next time...
#
defEvent(:CONNECTION_CHANGE, 1, true) do |event|
  ms('wimax_status').project(:signal).each do |sample|
    signal = sample.tuple
    if (signal == "No network") && property.connected
      property.connected = false
      event.fire
    elsif (signal != "No network") && !property.connected
      property.connected = true
      event.fire
    end
  end
end

# When the 'CONNECTION_CHANGE' event has fired, pause or resume the OML Proxy 
# server, depending on the current connection state
#
onEvent(:CONNECTION_CHANGE) do |event|
  if property.connected
    group('Cars').resumeDataCollection
  else 
    group('Cars').pauseDataCollection
  end
end

# When the Experiment is DONE, stop all applications
# The default OMF tasks associated to this event will be called after the
# tasks below, and will cleanly terminate the experiment
#
onEvent(:EXPERIMENT_DONE) do |event|
  group('Cars').stopApplications
  wait 10
  #group('Clouds').stopApplications
  #wait 10
end

