#
# Test 7
#
# Testing one node in one group running two instance of the same app, 
# previously defined with defApplication
#
# NOTE: in this example, while the defApp contains measurement point (MP) 
# definitions, these are not collected/enabled in the addApp using this 
# defined app. This is because here we simply use ping, which does not 
# have OML MPs... thus enabling these MPs will result in a command line 
# error when trying to run ping.
#

defProperty('res1', "unconfigured-node-1", "ID of a node")

defApplication('ping','ping') do |app|
  app.description = 'Simple App Def for Ping'
  app.binary_path = '/bin/ping'
  
  # OMF 5.4 SYNTAX
  #
  app.defProperty('target', "my target", nil, {:type => :string, :default => 'localhost'})
  app.defProperty('count', "my count", "-c", {:type => :integer, :default => 2, :order => 1})

  app.defMeasurement('ping_delay') do |m|
    m.defMetric('sequence', 'Fixnum')
    m.defMetric('destination', 'String')
    m.defMetric('rtt', 'Fixnum')
  end

  app.defMeasurement('ping_loss') do |m|
    m.defMetric('destination', 'String')
    m.defMetric('probe_count', 'Fixnum')
    m.defMetric('loss', 'Fixnum')
  end
  
  # OMF 6 SYNTAX
  #
  # app.define_parameter(
  #   :target => {:type => 'String', :default => 'localhost'},
  #   :count => {:type => 'Numeric', :cmd => '-c', :default => 2, :order => 1}
  # )
end

defGroup('Actor', property.res1) do |g|
  g.addApplication("ping") do |app|
    app.setProperty('target', 'www.google.com')
    app.setProperty('count', 1)
    #app.measure('ping_delay', :interval => 3)
  end
  g.addApplication("ping") do |app|
    app.setProperty('target', 'www.nicta.com.au')
    app.setProperty('count', 2)
    #app.measure('ping_loss', :samples => 10)
  end

end

onEvent(:ALL_UP_AND_INSTALLED) do |event|
  info "TEST - group"
  group("Actor").startApplications
  after 1.seconds do
    Experiment.done
  end
end
