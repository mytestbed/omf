defGroup('Sender', "omf.nicta.node9") do |node|
    defApplication('otg2') do |app|
        app.binary_path = "/usr/bin/otg2"
        app.description = "otg is a configurable traffic generator that sends packet streams"
        
        #Define properties
        app.defProperty('udp_local_host', 'IP address of this Source node', '--udp:local_host', {:type => :string, :dynamic => false})
        app.defProperty('udp_dst_host', 'IP address of the Destination', '--udp:dst_host', {:type => :string, :dynamic => false})
        app.defProperty('udp_broadcast', 'Broadcast', '--udp:broadcast', {:type => :integer, :dynamic => false})
        app.defProperty('udp_dst_port', 'Destination Port to send to', '--udp:dst_port', {:type => :integer, :dynamic => false})
        app.defMeasurement('udp_out') do |m|
            m.defMetric('ts',:float)
            m.defMetric('flow_id',:long)
            m.defMetric('seq_no',:long)
            m.defMetric('pkt_length',:long)
            m.defMetric('dst_host',:string)
            m.defMetric('dst_port',:long)
        
        #Set Properties
        app.setProperty('udp_local_host', '%net.w0.ip%')
        app.setProperty('udp_dst_host', '192.168.255.255')
        app.setProperty('udp_broadcast', 1)
        app.setProperty('udp_dst_port', 3000)
        app.measure('udp_out', :samples => 1)
    end
end
    

defGroup('Receiver', "omf.nicta.node10,omf.nicta.node11") do |node|
    defApplication('otr2') do |app|
        app.binary_path = "/usr/bin/otr2"
        app.description = "otr is a configurable traffic sink that recieves packet streams"
        
        app.defProperty('udp_local_host', 'IP address of this Destination node', '--udp:local_host', {:type => :string, :dynamic => false})
        app.defProperty('udp_local_port', 'Receiving Port of this Destination node', '--udp:local_port', {:type => :integer, :dynamic => false})
        app.defMeasurement('udp_in') do |m|
            m.defMetric('ts',:float)
            m.defMetric('flow_id',:long)
            m.defMetric('seq_no',:long)
            m.defMetric('pkt_length',:long)
            m.defMetric('dst_host',:string)
            m.defMetric('dst_port',:long)
        
        
        app.setProperty('udp_local_host', '192.168.255.255')
        app.setProperty('udp_local_port', 3000)
        app.measure('udp_in', :samples => 1)
    end
end

allGroups.net.w0 do |interface|
    interface.mode = "adhoc"
    interface.type = 'g'
    interface.channel = "6"
    interface.essid = "helloworld-tutorial04"
    interface.ip = "192.168.0.%index%"
end

onEvent(:ALL_UP_AND_INSTALLED) do |event|
    wait 10
    group("Receiver").startApplications
    wait 5
    group("Sender").startApplications
    wait 30
    group("Sender").stopApplications
    wait 5
    group("Receiver").stopApplications
    Experiment.done
end



