#Welcome to Experiment 06
#This ED will allow the experimenter to create a filter to customise measurements collected


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

onEvent(:ALL_UP_AND_INSTALLED) do |event|
    after 10
    allGroups.startApplications
    wait property.runtime / 2
    property.packetsize = 512
    wait property.runtime / 2
    allGroups.stopApplications
    Experiment.done
end