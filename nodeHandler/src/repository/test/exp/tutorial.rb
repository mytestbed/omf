#
# A)  Define the 'sender' group, which has the unique node [1,1]
#     Nodes in this group will execute the application 'test:proto:sender'
#
defGroup('source', [1,1]) {|node|
  node.prototype("test:proto:udp_sender", {
		'destinationHost' => '192.168.0.2',
		'localHost' => '192.168.0.1',
                'packetSize' => 256,
                'rate' => 8192
  })
  node.net.w0.mode = "master"
}

#
# B)  Define the 'receiver' group, which has the unique node [1,2]
#     Nodes in this group will execute the application 'test:proto:receiver'
#
defGroup('sink', [1,2]) {|node|
  node.prototype("test:proto:udp_receiver" , {
		'localHost' => '192.168.0.2'
  })
  node.net.w0.mode = "managed"
}

# 
# C)  Configure the wireless interfaces of All the Nodes involved in 
#     this experiment
#
allGroups.net.w0 { |w|
	w.type = 'g'
	w.channel = "6"
	w.essid = "helloworld"
	w.ip = "%192.168.0.%y" # the '%' triggers some substitutions
}

#
# D)  When all the nodes are turned On and the all the applications
#     are installed and ready, we can start to perform the experiment
#
whenAllInstalled() {|node|
  wait 30
  allGroups.startApplications
  wait 20
  Experiment.done
}
