#Welcome to Experiment 08: THE CONFERENCE ROOM

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
defProperty('hrnPrefix', "omf.nicta.node", "Prefix to use for the HRN of resources")
defProperty('resources', "[1,2,3,4,5,8,9,10,11,12,13]", "List of IDs for the resources to use as senders")
defProperty('receiver', "6", "ID for the resource to use as a receiver")
defProperty('groupSize', 4, "Number of resources to put in each group of senders")
defProperty('rate', 300, 'Bits per second sent from senders')
defProperty('packetSize', 256, 'Byte size of packets sent from senders')
defProperty('wifiType', "g", "The type of WIFI to use in this experiment")
defProperty('channel', '6', "The WIFI channel to use in this experiment")
defProperty('netid', "confroom", "The ESSID to use in this experiment")
defProperty('stepDuration', 60, "The duration of each step of this conf-room")

#Define the Receiver
defGroup('Receiver', "#{property.hrnPrefix}#{property.receiver}") do |node|
    node.addApplication("otr2") do |app|
        app.setProperty('udp_local_host', '%net.w0.ip%')
        app.setProperty('udp_local_port', 3000)
        app.measure('udp_in', :samples => 1)
    end
    node.net.w0.mode = "master"
    node.net.w0.type = property.wifiType
    node.net.w0.channel = property.channel
    node.net.w0.essid = property.netid
    node.net.w0.ip = "192.168.0.254"
end

#Define each Sender groups
groupList = []
res = eval(property.resources.value)
groupNumber = res.size >= property.groupSize ? (res.size.to_f / property.groupSize.value.to_f).ceil : 1
(1..groupNumber).each do |i|
    list = []
    (1..property.groupSize).each do |j| popped = res.pop ; list << popped if !popped.nil?  end
    senderNames = list.collect do |id| "#{property.hrnPrefix}#{id}" end
    senders = senderNames.join(',')
    
    info "Group Sender #{i}: '#{senders}'"
    groupList << "Sender#{i}"
    defGroup("Sender#{i}", senders) do |node|
        node.addApplication("otg2") do |app|
            app.setProperty('udp_local_host', '%net.w0.ip%')
            app.setProperty('udp_dst_host', '192.168.0.254')
            app.setProperty('udp_dst_port', 3000)
            app.setProperty('cbr_size', property.packetSize)
            app.setProperty('cbr_rate', property.rate)
            app.measure('udp_out', :samples => 1)
        end
        
        #Currently not working - new syntax required for experiment to work
        node.net.w0.mode = "managed"
        node.net.w0.type = property.wifiType
        node.net.w0.channel = property.channel
        node.net.w0.essid = property.netid
        node.net.w0.ip = "192.168.0.%index%"
    end
end

#Section 3
#Execution of application events
onEvent(:ALL_UP_AND_INSTALLED) do |event|
    info "Initializing the Conference Room..."
    
    after 10
    group('Receiver').startApplications
    info "The Conference Room has started..."

    after 20
    (1..groupNumber).each do |i|
        group("Sender#{i}").startApplications
        after property.stepDuration
    end
    (1..groupNumber).each do |i|
        group("Sender#{i}").stopApplications
        after property.stepDuration
    end
    group('Receiver').stopApplications
    info "Applications are stopping... Conference Room experiment Complete."
    Experiment.done
end



