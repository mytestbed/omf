#
# Test 3
#
# Testing 2 nodes in 2 groups running already installed OTG/OTR
# Also testing static experiment properties
# Also testing wireless interface configuration
#

defProperty('res1', "unconfigured-node-1", "ID of a node")
defProperty('res2', "unconfigured-node-2", "ID of a node")
defProperty('mode1', "adhoc", "wifi mode for 1st node")
defProperty('mode2', "adhoc", "wifi mode for 2nd node")
defProperty('wifi', "g", "wifi type to use")
defProperty('channel', "6", "wifi channel to use")

defGroup('Sender', property.res1) {|node|
  node.addApplication("test:app:otg2") {|app|
    app.setProperty('udp:local_host', '192.168.0.2')
    app.setProperty('udp:dst_host', '192.168.0.3')
    app.setProperty('udp:dst_port', 3000)
    app.measure('udp_out', :interval => 3)
  }
  node.net.w0.mode = property.mode1
  node.net.w0.type = property.wifi
  node.net.w0.channel = property.channel
  node.net.w0.essid = "testing"
  node.net.w0.ip = "192.168.0.2"
}

defGroup('Receiver', property.res2) {|node|
  node.addApplication("test:app:otr2") {|app|
    app.setProperty('udp:local_host', '192.168.0.3')
    app.setProperty('udp:local_port', 3000)
    app.measure('udp_in', :samples => 3)
  }
  node.net.w0.mode = property.mode2
  node.net.w0.type = property.wifi
  node.net.w0.channel = property.channel
  node.net.w0.essid = "testing"
  node.net.w0.ip = "192.168.0.3"
}

onEvent(:ALL_UP_AND_INSTALLED) do |event|
  wait 10
  allGroups.startApplications
  wait 10
  info "TEST - Running ifconfig on Sender"
  group('Sender').exec("/sbin/ifconfig")
  wait 15
  info "TEST - Running ifconfig on Receiver"
  group('Receiver').exec("/sbin/ifconfig")
  wait 15
  allGroups.stopApplications
  Experiment.done
end
