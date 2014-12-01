# 1. Define an OMF Application Definition for the ping-oml2 application
# The OMF entities are using this definition to know where to find the
# application, what are its configurable parameters, and what are the
# OML2 measurement points that it provides.
# This ping-oml2 application will be known by OMF entities as 'ping_oml2'
#
defApplication('ping_oml2') do |app|
  app.description = 'Simple Definition for the ping-oml2 application'
  # Define the path to the binary executable for this application
  app.binary_path = '/usr/bin/ping-oml2'
  # Define the configurable parameters for this application
  # For example if target is set to foo.com and count is set to 2, then the
  # application will be started with the command line:
  # /usr/bin/ping-oml2 -a foo.com -c 2
  app.defProperty('target', 'Address to ping', '-a', {:type => :string})
  app.defProperty('count', 'Number of times to ping', '-c', {:type => :integer})
  # Define the OML2 measurement point that this application provides.
  # Here we have only one measurement point (MP) named 'ping'. Each measurement
  # sample from this MP will be composed of a 4-tuples (addr,ttl,rtt,rtt_unit)
  app.defMeasurement('ping') do |m|
    m.defMetric('dest_addr',:string)
    m.defMetric('ttl',:uint32)
    m.defMetric('rtt',:double)
    m.defMetric('rtt_unit',:string)
  end
end

# 2. Define a group of resources which will run the ping-oml2 application
# Here we define only one group (Sender), which has only one resource in it
# (omf.nicta.node8)
#
defGroup('Sender', 'omf.nicta.node8') do |g|
  # Associate the application ping_oml2 defined above to each resources
  # in this group
  g.addApplication("ping_oml2") do |app|
    # Configure the parameters for the ping_oml2 application
    app.setProperty('target', 'www.nicta.com.au')
    app.setProperty('count', 3)
    # Request the ping_oml2 application to collect measurement samples
    # from the 'ping' measuremnt point (as defined above), and send them
    # to an OML2 collection point
    app.measure('ping', :samples => 1)
  end
end

# 3. Define the sequence of tasks to perform when the event
# "all resources are up and all applications are install" is being triggered
#
onEvent(:ALL_UP_AND_INSTALLED) do |event|
  # Print some information message
  info "This is my first OMF experiment"
  # Start all the Applications associated to all the Groups
  allGroups.startApplications
  # After 5 sec
  after 5 do
    # Stop all the Applications associated to all the Groups
    allGroups.stopApplications
    # Tell the Experiment Controller to terminate the experiment now
    Experiment.done
  end
end
