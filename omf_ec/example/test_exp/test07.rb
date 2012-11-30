#
# Test 7
#
# Testing one node in one group running two instance of the same app, previously defined with defApplication
#

defProperty('res1', "unconfigured-node-1", "ID of a node")

defApplication('ping','ping') do |app|
  app.description = 'Simple App Def for Ping'
  app.binary_path = '/bin/ping'
  
  # OMF 5.4 SYNTAX
  #
  app.defProperty('target', "my target", nil, {:type => :string, :default => 'localhost'})
  app.defProperty('count', "my count", "-c", {:type => :integer, :default => 2, :order => 1})

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
    #app.measure('udp_out', :interval => 3)
  end
  g.addApplication("ping") do |app|
    app.setProperty('target', 'www.nicta.com.au')
    app.setProperty('count', 2)
    #app.measure('udp_out', :interval => 3)
  end

end

onEvent(:ALL_UP_AND_INSTALLED) do |event|
  info "TEST - group"
  group("Actor").startApplications
  after 10.seconds do
    Experiment.done
  end
end
