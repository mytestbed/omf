#Welcome to Experiment 08: THE CONFERENCE ROOM

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

# Define the Receiver
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

# Define each Sender groups
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
        node.net.w0.mode = "managed"
        node.net.w0.type = property.wifiType
        node.net.w0.channel = property.channel
        node.net.w0.essid = property.netid
        node.net.w0.ip = "192.168.0.%index%"
    end
end

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



