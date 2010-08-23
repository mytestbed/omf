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
  info "TEST - Sender WIFI"
  group('Sender').exec("/sbin/wlanconfig ath0 ; ifconfig ath0")
  wait 10
  info "TEST - Receiver WIFI"
  group('Receiver').exec("/sbin/wlanconfig ath0 ; ifconfig ath0")
  wait 20
  allGroups.stopApplications
  Experiment.done
end


#
# Checking the Execution
# Here you do whatever is required to check that the above experiment went well
# Then return true if you decided that it did, or false otherwise
#
# Experiment log file is at: property.logpath
# Also you may want to look at system:exp:testlib
#

def check_outcome

  # Test 01 is successfull if for each of the 2 exec commands above, the log 
  # file has a message from the AgentCommands module containing "DONE.OK"
  logfile = "#{property.logpath}/#{Experiment.ID}.log"
  lines = IO.readlines("#{logfile}")
  match1 = lines.grep(/DONE\.OK/)
  result = (match1.length == 2) ? true : false
  result = true
  return result
end
