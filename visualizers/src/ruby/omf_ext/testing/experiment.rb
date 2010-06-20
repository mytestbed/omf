
#
# A)  Define the 'sender' group, which has the unique node [1,1]
#     Nodes in this group will execute the application 'test:proto:sender'
#
defGroup('source', [1,102]) {|node|
  node.prototype("test:proto:udp_sender", {
    'destinationHost' => '192.168.1.10',
    'localHost' => '192.168.1.102',
                'packetSize' => 128, # in Byte
                'rate' => 4096 # in bits per second
  })
  # NOTE: a packet of 128 Bytes at a rate of 4096 bits/s = 4 pkt/sec
}

#
# B)  Define the 'receiver' group, which has the unique node [1,2]
#     Nodes in this group will execute the application 'test:proto:receiver'
#
defGroup('sink', [1,10]) {|node|
  node.prototype("test:proto:udp_receiver" , {
    'localHost' => '192.168.1.10'
  })
}

#
# C)  Turn ON Disconnection Mode for all the groups in this experiment
#
allGroups.allowDisconnection

# 
# D)  Configure the wireless interfaces of All the Nodes involved in 
#     this experiment
#
allGroups.net.w0 { |w|
  w.mode = "adhoc"
  w.type = 'b'
  w.channel = "1"
  w.essid = "vehicledemo"
  w.ip = "%192.168.1.%y" # the '%' triggers some substitutions
}

#
# E)  Define a graph to visualize results
#
defGraph 'pkts_received' {|g|
  g.select '**/otr/receiverport/' {|t|
    t.select 'pkt_seqno', :show => g.AXIS_Y
    t.select '_ts_client', :show => g.AXIS_X
  }
}

#
# F)  When all the nodes are turned ON and all the applications
#     are installed and ready, we can start to perform the experiment
#
whenAllInstalled() {|node|

  # Now start all the applications on all the groups
  info "Experiment - Starting all Applications" 
  allGroups.startApplications

  # Now wait for 10min (= 600sec) while the vehicle are moving around on the campus...
  # NOTE: Please update that time to match full travel time of vehicle from base to base
  wait 180

  # Now stop all the applications on all the groups
  info "Experiment - Stopping all Applications" 
  allGroups.stopApplications

  # Wait an extra 30sec to let applications terminate nicely
  wait 15

  # Now terminate the Experiment
  Experiment.done
}
