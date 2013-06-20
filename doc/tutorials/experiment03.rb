#Welcome to the Dynamic Properties ED
#This ED allows the experimenter to pass parameters to the experiment and change them at run-time

###############################################################################################
###############################################################################################
#Section 1
#Define application file-paths
#Define experiment parameters and measurement points

defApplication('otg2') do |app|
    
	#Application description and binary path
	app.description = 'otg2 is a configurable traffic generator'
	app.binary_path = '/usr/bin/otg2'
    
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


defApplication('otr2') do |app|
    
	#Application description and binary path
	app.description = 'otr2 is a configurable traffic reciever'
	app.binary_path = '/usr/bin/otr2'
    
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

###############################################################################################
###############################################################################################
#Define dynamic properties

defProperty('theSender', 'omf.nicta.node9', "ID of sender node")
defProperty('theReceiver', 'omf.nicta.node10', "ID of receiver node")
defProperty('packetsize', 128, "Packet size (byte) from the sender node")
defProperty('bitrate', 2048, "Bitrate (bit/s) from the sender node")
defProperty('runtime', 40, "Time in second for the experiment is to run")
defProperty('wifiType', "g", "The type of WIFI to use in this experiment")
defProperty('channel', '6', "The WIFI channel to use in this experiment")
defProperty('netid', "example2", "The ESSID to use in this experiment")

###############################################################################################
###############################################################################################
#Section 2
#Define resources and nodes used by oml2 application

#Create the group 'Sender' associated to dynamic property
defGroup('Sender',property.theSender) do |node|
    
	#Associate oml2 application to group (?)
	g.addApplication("otg2") do |app|
        
		#Configure aplication
        app.setProperty('udp_local_host', '192.168.0.2')
        app.setProperty('udp_dst_host', '192.168.0.3')
        app.setProperty('udp_dst_port', 3000)
        app.setProperty('cbr_size', property.packetsize)
        app.setProperty('cbr_rate', property.bitrate * 2)
        
		#Request application to collect measurement point output data
        app.measure('udp_out', :samples => 1)
        
	end
    node.net.w0.mode = "adhoc"
    node.net.w0.type = property.wifiType
    node.net.w0.channel = property.channel
    node.net.w0.essid = "foo"+property.netid
    node.net.w0.ip = "192.168.0.2/24"
end

#Create the group 'Reciever' associated to dynamic property
defGroup('Reciever',property.theReceiver) do |node|
    
	#Associate oml2 application to group (?)
	g.addApplication("otg2") do |app|
        
		#Configure application
        app.setProperty('udp_local_host', '192.168.0.3')
        app.setProperty('udp_local_port', 3000)
        
		#Request application to collect measurement point output data
        app.measure('udp_in', :samples => 1)

	end
    node.net.w0.mode = "adhoc"
    node.net.w0.type = property.wifiType
    node.net.w0.channel = property.channel
    node.net.w0.essid = "foo"+property.netid
    node.net.w0.ip = "192.168.0.3/24"
end


###############################################################################################
###############################################################################################
#Section  3
#Execution of application events

onEvent(:ALL_UP_AND_INSTALLED) do |event|
    
    info "Starting dynamic properties ED..."
    wait 10
    
    allGroups.startApplications
    info "Applications have started..."
    
    wait property.runtime / 4
    property.packetsize = 256
    wait property.runtime / 4
    property.packetsize = 512
    wait property.runtime / 4
    property.packetsize = 1024
    wait property.runtime / 4
    
    allGroups.stopApplications
    info "Applications are stopping... Experiment complete."
    Experiment.done
end


