#Welcome to Experiment 01
#This ED allows experimenters to ping a specified host and collect the output it recieves as measurement points


#Section 1
#Define oml2 application file-paths
#Define experiment parameters and measurement points

defApplication('ping_oml2') do |app|
    
	#Application description and binary path
	app.description = 'Simple definition of ping-oml2 application'
	app.binary_path = '/usr/bin/ping-oml2'
    
	#Configurable parameters of Experiment
	app.defProperty('target', 'Address to ping', '-a', {:type => :string})
	app.defProperty('count', 'Number of times to ping', '-c', {:type => :integer})
    
	
	#Define measurement points that application will output
	app.defMeasurement('ping') do |m|
        m.defMetric('dest_addr',:string)
        m.defMetric('ttl',:uint32)
        m.defMetric('rtt',:double)
        m.defMetric('rtt_unit',:string)
        
    end
end

#Section 2
#Define resources and nodes used by oml2 application

#Create the group 'Sender' with specified nodes
defGroup('Sender', 'omf.nicta.node9') do |g|
    
	#Associate oml2 application to group (?)
	g.addApplication("ping_oml2") do |app|
        
		#Configure target of application (Ping target)
		app.setProperty('target', 'www.nicta.com.au')
		
		#Configure amount of times to ping host
		app.setProperty('count', 3)
        
		#Request application to collect measurement point output data
		app.measure('ping', :samples => 1)
        
	end
end

#Section  3
#Execution of application events

onEvent(:ALL_UP_AND_INSTALLED) do |event|
	
    # Print information message on commandline
    info "Initializing first OMF experiment event"
    
    # Start all the Applications associated to all the Group
    allGroups.startApplications
    
    # Wait for 5 sec (allowing time for 3 pings)
    after 5
	
    # Stop all the Applications associated to all the Groups
    allGroups.stopApplications
    
    # Tell the Experiment Controller to terminate the experiment now
    Experiment.done
end


