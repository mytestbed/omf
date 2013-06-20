#Welcome to Experiment 06
#This ED will allow the experimenter to create a filter to customise measurements collected
#Section 1
#Define otr2 application file-paths
#Define experiment parameters and measurement points

defApplication('otr2') do |a|
    
    
	#Application description and binary path
    a.binary_path = "/usr/bin/otr2"
    a.description = "otr is a configurable traffic sink that recieves packet streams"
    
    #Define configurable parameters of otr2
    a.defProperty('udp_local_host', 'IP address of this Destination node', '--udp:local_host', {:type => :string, :dynamic => false})
    a.defProperty('udp_local_port', 'Receiving Port of this Destination node', '--udp:local_port', {:type => :integer, :dynamic => false})
    a.defMeasurement('udp_in') do |m|
        m.defMetric('ts',:float)
        m.defMetric('flow_id',:long)
        m.defMetric('seq_no',:long)
        m.defMetric('pkt_length',:long)
        m.defMetric('dst_host',:string)
        m.defMetric('dst_port',:long)
    end
end

#Define otg2 application file-paths
#Define experiment parameters and measurement points
defApplication('otg2') do |a|
    
    #Application description and binary path
    a.binary_path = "/usr/bin/otg2"
    a.description = "otg is a configurable traffic generator that sends packet streams"
    
    #Define configurable parameters of otg2
    a.defProperty('generator', 'Type of packet generator to use (cbr or expo)', '-g', {:type => :string, :dynamic => false})
    a.defProperty('udp_broadcast', 'Broadcast', '--udp:broadcast', {:type => :integer, :dynamic => false})
    a.defProperty('udp_dst_host', 'IP address of the Destination', '--udp:dst_host', {:type => :string, :dynamic => false})
    a.defProperty('udp_dst_port', 'Destination Port to send to', '--udp:dst_port', {:type => :integer, :dynamic => false})
    a.defProperty('udp_local_host', 'IP address of this Source node', '--udp:local_host', {:type => :string, :dynamic => false})
    a.defProperty('udp_local_port', 'Local Port of this source node', '--udp:local_port', {:type => :integer, :dynamic => false})
    a.defProperty("cbr_size", "Size of packet [bytes]", '--cbr:size', {:dynamic => true, :type => :integer})
    a.defProperty("cbr_rate", "Data rate of the flow [kbps]", '--cbr:rate', {:dynamic => true, :type => :integer})
    a.defProperty("exp_size", "Size of packet [bytes]", '--exp:size', {:dynamic => true, :type => :integer})
    a.defProperty("exp_rate", "Data rate of the flow [kbps]", '--exp:rate', {:dynamic => true, :type => :integer})
    a.defProperty("exp_ontime", "Average length of burst [msec]", '--exp:ontime', {:dynamic => true, :type => :integer})
    a.defProperty("exp_offtime", "Average length of idle time [msec]", '--exp:offtime', {:dynamic => true, :type => :integer})
    
    #Define measurement points that application will output
    a.defMeasurement('udp_out') do |m|
        m.defMetric('ts',:float)
        m.defMetric('flow_id',:long)
        m.defMetric('seq_no',:long)
        m.defMetric('pkt_length',:long)
        m.defMetric('dst_host',:string)
        m.defMetric('dst_port',:long)
        
    end
end

#Section 2
#Define resources and nodes used by application

defProperty('theSender', 'omf.nicta.node9', "ID of sender node")
defProperty('theReceiver', 'omf.nicta.node10', "ID of receiver node")
defProperty('packetsize', 256, "Packet size (byte) from the sender node")
defProperty('runtime', 30, "Time in second for the experiment is to run")


defGroup('Sender',property.theSender) do |node|
    node.addApplication("otg2") do |app|
        app.setProperty('udp_local_host', '192.168.0.2')
        app.setProperty('udp_dst_host', '192.168.0.3')
        app.setProperty('udp_dst_port', 3000)
        app.setProperty('cbr_size', property.packetsize)
        app.measure('udp_out', :samples => 3) do |mp|
            mp.filter('seq_no', 'avg')
        end
    end
    node.net.w0.mode = "adhoc"
    node.net.w0.type = 'g'
    node.net.w0.channel = "6"
    node.net.w0.essid = "Hello World! Experiment06"
    node.net.w0.ip = "192.168.0.2/24"
end

defGroup('Receiver',property.theReceiver) do |node|
    node.addApplication("otr2") do |app|
        app.setProperty('udp_local_host', '192.168.0.3')
        app.setProperty('udp_local_port', 3000)
        app.measure('udp_in', :samples => 2) do |mp|
            mp.filter('pkt_length', 'sum')
            mp.filter('seq_no', 'avg')
        end
    end
    node.net.w0.mode = "adhoc"
    node.net.w0.type = 'g'
    node.net.w0.channel = "6"
    node.net.w0.essid = "Hello World! Experiment06"
    node.net.w0.ip = "192.168.0.3/24"
end

#Section 3
#Execution of application events
onEvent(:ALL_UP_AND_INSTALLED) do |event|
    info "Starting experiment events..."
    
    after 10
    allGroups.startApplications
    info "All Applications have started..."
    
    after property.runtime / 2
    property.packetsize = 512
    after property.runtime / 2
    
    allGroups.stopApplications
    info "Applications are stopping... Experiment Complete."
    Experiment.done
end