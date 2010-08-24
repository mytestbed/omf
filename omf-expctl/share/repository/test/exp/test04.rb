#
# Test 4
#
# Testing 2 nodes in 2 groups running already installed OTG/OTR
# Also testing dynamic experiment properties
#

PKTSIZE = 256

defProperty('res1', "unconfigured-node-1", "ID of a node")
defProperty('res2', "unconfigured-node-2", "ID of a node")
defProperty('bitrate', 2048, "Bitrate (bit/s) from the sender node")
defProperty('packetsize', PKTSIZE, "Packet size (byte) from the sender node")

defGroup('Sender', property.res1) {|node|
  node.addApplication("test:app:otg2") {|app|
    app.setProperty('udp:local_host', '192.168.0.2')
    app.setProperty('udp:dst_host', '192.168.0.3')
    app.setProperty('udp:dst_port', 3000)
    app.setProperty('cbr:rate', property.bitrate * 2)
    app.setProperty('cbr:size', property.packetsize)
    app.measure('udp_out', :interval => 3)
  }
  node.net.w0.mode = "adhoc"
  node.net.w0.type = 'g'
  node.net.w0.channel = '6'
  node.net.w0.essid = "testing"
  node.net.w0.ip = "192.168.0.2"
}

defGroup('Receiver', property.res2) {|node|
  node.addApplication("test:app:otr2") {|app|
    app.setProperty('udp:local_host', '192.168.0.3')
    app.setProperty('udp:local_port', 3000)
    app.measure('udp_in', :samples => 3)
  }
  node.net.w0.mode = "adhoc"
  node.net.w0.type = 'g'
  node.net.w0.channel = '6'
  node.net.w0.essid = "testing"
  node.net.w0.ip = "192.168.0.3"
}

onEvent(:ALL_UP_AND_INSTALLED) do |event|
  wait 10
  allGroups.startApplications
  wait 15
  info "------------------------------"
  info "TEST - Dynamic property change"
  info "TEST - Value before: #{property.packetsize}"
  property.packetsize = 512
  info "TEST - Value after: #{property.packetsize}"
  wait 15
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

  # Test 04 is successfull if all of the following are true:
  # 1) each resource reports that all its wireless property were configured OK
  # 2) the applications (OTG,OTR,execs) started and finished properly
  # file has a message from the AgentCommands module containing "DONE.OK"
  # 3) a SQ3 database is produced with some entries in the OTG and OTR tables
  # 4) the receiver table of the database has the packetsize value increasing
  logfile = "#{property.logpath}/#{Experiment.ID}.log"
  lines = IO.readlines("#{logfile}")
  # 1)
  match1 = lines.grep(/CONFIGURED\.OK/)
  r1 = (match1.length >= 10) ? true : false
  # 2) 
  match1 = lines.grep(/APP_EVENT\ STARTED/)
  r2 = (match1.length == 2) ? true : false
  match1 = lines.grep(/APP_EVENT DONE\.OK/)
  match2 = match1.grep(/AgentCommands/)
  r3 = (match2.length == 2) ? true : false
  # 3)
  cnt1 = cnt2 = 0
  ms('udp_out').project(:oml_ts_server).each { |r| cnt1 =+1 }
  ms('udp_in').project(:oml_ts_server).each { |r| cnt2 =+1 }
  r4 = (cnt1 >= 1) ? true : false
  r5 = (cnt2 >= 1) ? true : false
  # 4)
  max = PKTSIZE
  ms('udp_in').project(:pkt_length_max).each do |r| 
    value = r.tuple
    max = value[0]
  end
  r6 = (max > PKTSIZE) ? true : false

  puts "Check Outcome [r1:#{r1} - r2:#{r2} - r3:#{r3} - r4:#{r4} - r5:#{r5} - r6:#{r6}]"
  return true if r1 && r2 && r3 && r4 && r5 && r6
  return false
end
