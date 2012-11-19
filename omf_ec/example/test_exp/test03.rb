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
  #node.addApplication("test:app:otg2") {|app|
  #  app.setProperty('udp:local_host', '192.168.0.2')
  #  app.setProperty('udp:dst_host', '192.168.0.3')
  #  app.setProperty('udp:dst_port', 3000)
  #  app.measure('udp_out', :interval => 3)
  #}
  node.net.w0.mode = property.mode1
  node.net.w0.type = property.wifi
  node.net.w0.channel = property.channel
  node.net.w0.essid = "testing"
  node.net.w0.ip = "192.168.0.2"
}

defGroup('Receiver', property.res2) {|node|
  #node.addApplication("test:app:otr2") {|app|
  #  app.setProperty('udp:local_host', '192.168.0.3')
  #  app.setProperty('udp:local_port', 3000)
  #  app.measure('udp_in', :samples => 3)
  #}
  node.net.w0.mode = property.mode2
  node.net.w0.type = property.wifi
  node.net.w0.channel = property.channel
  node.net.w0.essid = "testing"
  node.net.w0.ip = "192.168.0.3"
}

#onEvent(:ALL_UP_AND_INSTALLED) do |event|
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
#end


#
# Checking the Execution
# Here you do whatever is required to check that the above experiment went well
# Then return true if you decided that it did, or false otherwise
#
# Experiment log file is at: property.logpath
# Also you may want to look at system:exp:testlib
#

def check_outcome

  # Test 03 is successfull if all of the following are true:
  # 1) each resource reports that all its wireless property were configured OK
  # 2) the applications (OTG,OTR,execs) started and finished properly
  # file has a message from the AgentCommands module containing "DONE.OK"
  # 3) a SQ3 database is produced with some entries in the OTG and OTR tables
  logfile = "#{property.logpath}/#{Experiment.ID}.log"
  lines = IO.readlines("#{logfile}")
  # 1)
  match1 = lines.grep(/CONFIGURED\.OK/)
  r1 = (match1.length >= 10) ? true : false
  # 2)
  match1 = lines.grep(/APP_EVENT\ STARTED/)
  r2 = (match1.length == 4) ? true : false
  match1 = lines.grep(/APP_EVENT DONE\.OK/)
  match2 = match1.grep(/AgentCommands/)
  r3 = (match2.length == 4) ? true : false
  # 3)
  cnt1 = cnt2 = 0
  ms('udp_out').project(:oml_ts_server).each { |x| cnt1 =+1 }
  ms('udp_in').project(:oml_ts_server).each { |x| cnt2 =+1 }
  r4 = (cnt1 >= 1) ? true : false
  r5 = (cnt2 >= 1) ? true : false

  puts "Check Outcome [r1:#{r1} - r2:#{r2} - r3:#{r3} - r4:#{r4} - r5:#{r5}]"
  return true if r1 && r2 && r3 && r4 && r5
  return false
end
