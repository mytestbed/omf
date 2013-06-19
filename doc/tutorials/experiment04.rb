defGroup('Sender', "omf.nicta.node9") do |node|
    defApplication('otg2') do |a|
        a.binary_path = "/usr/bin/otg2"
        a.description = "otg is a configurable traffic generator that sends packet streams"
        app.setProperty('udp_local_host', '%net.w0.ip%')
        app.setProperty('udp_dst_host', '192.168.255.255')
        app.setProperty('udp_broadcast', 1)
        app.setProperty('udp_dst_port', 3000)
        app.measure('udp_out', :samples => 1)
    end
end

defGroup('Receiver', "omf.nicta.node10") do |node|
    defApplication('otr2') do |a|
        a.binary_path = "/usr/bin/otr2"
        a.description = "otr is a configurable traffic sink that recieves packet streams"
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



