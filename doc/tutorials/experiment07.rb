#Welcome to Experiment 07
#This ED will allow the experimenter to use OMF Prototypes to specify the Application
#A Prototype is a specialized version of your applicationwith preset parameters and measurement collection points

defGroup('CBR_Sender', "omf.nicta.node9") do |node|
    options = { 'localHost' => '%net.w0.ip%',
        'destinationHost' => '192.168.255.255',
        'packetSize' => 256 }
    node.addPrototype("cbr_generator", options)
end

defGroup('EXPO_Sender', "omf.nicta.node9") do |node|
    options = { 'localHost' => '%net.w0.ip%',
        'destinationHost' => '192.168.255.255',
        'packetSize' => 1024 }
    node.addPrototype("expo_generator", options)
end

defGroup('Receiver', "omf.nicta.node10") do |node|
    node.addApplication("otr2") do |app|
        app.setProperty('udp_local_host', '192.168.255.255')
        app.setProperty('udp_local_port', 3000)
        app.measure('udp_in', :samples => 1)
    end
end

#Currently not working
allGroups.net.w0 do |interface|
    interface.mode = "adhoc"
    interface.type = 'g'
    interface.channel = "6"
    interface.essid = "Hello World! Experiment07"
    interface.ip = "192.168.0.%index%"
end

onEvent(:ALL_UP_AND_INSTALLED) do |event|
    after 10
    info "Starting the Receiver"
    group("Receiver").startApplications
    info "Starting the EXPO-traffic Sender"
    group("EXPO_Sender").startApplications
    after 50
    info "Stopping the EXPO-traffic Sender"
    group("EXPO_Sender").stopApplications
    after 55
    info "Starting the CBR-traffic Sender"
    group("CBR_Sender").startApplications
    after 95
    info "Now stopping all everything"
    #allGroups.stopApplications
    group("CBR_Sender").stopApplications
    group("Receiver").stopApplications
    Experiment.done
end