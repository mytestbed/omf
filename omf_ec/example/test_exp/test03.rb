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
  node.net.w0.mode = property.mode1
  node.net.w0.type = property.wifi
  node.net.w0.channel = property.channel
  node.net.w0.essid = "testing"
  node.net.w0.ip = "192.168.0.10/24"
}

defGroup('Receiver', property.res2) {|node|
  node.net.w0.mode = property.mode2
  node.net.w0.type = property.wifi
  node.net.w0.channel = property.channel
  node.net.w0.essid = "testing"
  node.net.w0.ip = "192.168.0.20/24"
}

onEvent(:ALL_INTERFACE_UP) do |event|
  info "TEST - Running ifconfig on Sender"
  group('Sender').exec("/sbin/ifconfig")

  info "TEST - Running ifconfig on Receiver"
  group('Receiver').exec("/sbin/ifconfig")

  after 30.seconds do
    Experiment.done
  end
end
