defProperty('theSender', 'omf.nicta.node9', "ID of sender node")
defProperty('theReceiver', 'omf.nicta.node10', "ID of receiver node")
defProperty('packetsize', 128, "Packet size (byte) from the sender node")
defProperty('bitrate', 2048, "Bitrate (bit/s) from the sender node")
defProperty('runtime', 40, "Time in second for the experiment is to run")
defProperty('wifiType', "g", "The type of WIFI to use in this experiment")
defProperty('channel', '6', "The WIFI channel to use in this experiment")
defProperty('netid', "example2", "The ESSID to use in this experiment")

defGroup('Sender',property.theSender) do |node|
    node.addApplication("test:app:otg2") do |app|
        app.setProperty('udp:local_host', '192.168.0.2')
        app.setProperty('udp:dst_host', '192.168.0.3')
        app.setProperty('udp:dst_port', 3000)
        app.setProperty('cbr:size', property.packetsize)
        app.setProperty('cbr:rate', property.bitrate * 2)
        app.measure('udp_out', :samples => 1)
    end
    node.net.w0.mode = "adhoc"
    node.net.w0.type = property.wifiType
    node.net.w0.channel = property.channel
    node.net.w0.essid = "foo"+property.netid
    node.net.w0.ip = "192.168.0.2"
end

defGroup('Receiver',property.theReceiver) do |node|
    node.addApplication("test:app:otr2") do |app|
        app.setProperty('udp:local_host', '192.168.0.3')
        app.setProperty('udp:local_port', 3000)
        app.measure('udp_in', :samples => 1)
    end
    node.net.w0.mode = "adhoc"
    node.net.w0.type = property.wifiType
    node.net.w0.channel = property.channel
    node.net.w0.essid = "foo"+property.netid
    node.net.w0.ip = "192.168.0.3"
end

onEvent(:ALL_UP_AND_INSTALLED) do |event|
    info "This is my first OMF experiment"
    wait 10
    allGroups.startApplications
    info "All my Applications are started now..."
    wait property.runtime / 4
    property.packetsize = 256
    wait property.runtime / 4
    property.packetsize = 512
    wait property.runtime / 4
    property.packetsize = 1024
    wait property.runtime / 4
    allGroups.stopApplications
    info "All my Applications are stopped now."
    Experiment.done
end



