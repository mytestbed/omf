#
# This OMF script defines and runs the  GEC-12 demo.
# Demonstrates storage-aware routing, multi-homing, and gnrs for GUID resolution
#

defApplication('MF-Router', 'router') {|app|
    app.shortDescription = "Click-based MF Router"
    #should take 3 args: 1st one for IDing whether it should be sdr, rtr or recver. 2nd is my_GUID
    app.path = "/usr/local/mobilityfirst/scripts/init_click.sh" #script for running click configuration 
    app.defProperty('type', 'sender=1,router=2,receiver=3', nil,{:type => :integer,:dynamic => false, :use_name => false, :order => 1})
    app.defProperty('my_GUID', 'my own GUID', nil,{:type => :integer,:dynamic => false, :use_name => false, :order => 2})
    app.defProperty('topo_URL', 'URL for topology file', nil,{:type => :string,:dynamic => false, :use_name => false, :order => 3})
    app.defProperty('dev', 'network interface', nil,{:type => :string,:dynamic => false, :use_name => false, :order => 4})
}

defApplication('MF-GNRS', 'gnrs') {|app|
    app.shortDescription = "GNRS Server"
    app.path = "/usr/local/mobilityfirst/scripts/init_gnrsd.sh" 
    app.defProperty('config_file', 'Configuration file', nil,{:type => :string,:dynamic => false, :use_name => false, :order => 1})
    app.defProperty('self_ip', 'Server IP', nil,{:type => :string,:dynamic => false, :use_name => false, :order => 2})
    app.defProperty('dev', 'network interface', nil,{:type => :string,:dynamic => false, :use_name => false, :order => 3})
    app.defProperty('srvrs_file', 'Servers list file', nil,{:type => :string,:dynamic => false, :use_name => false, :order => 4})
}

defApplication('Access-Bridge', 'access-bridge') {|app|
    app.shortDescription = "Access Bridge for wireless client"
    app.path = "/bin/bash" 
    app.defProperty('cmd', 'cmdline to run bridge', nil,{:type => :string,:dynamic => false, :use_name => false, :order => 1})
}

defApplication('MF-Linux-Client-Stack', 'lnx-client-stack') {|app|
    app.shortDescription = "MF linux client stack"
    app.path = "/usr/local/mobilityfirst/scripts/init_client_stack.sh" 
    app.defProperty('my_GUID', 'my own GUID', nil,{:type => :integer,:dynamic => false, :use_name => false, :order => 1})
    app.defProperty('ifs_file', 'interface configuration file', nil,{:type => :string,:dynamic => false, :use_name => false, :order => 2})
    app.defProperty('policy_file', 'Network Manager policy', nil,{:type => :string,:dynamic => false, :use_name => false, :order => 3})
    app.defProperty('wifi_ip', 'IP for wifi interface', nil,{:type => :string,:dynamic => false, :use_name => false, :order => 4})
    app.defProperty('wimax_ip', 'IP for wimax interface', nil,{:type => :string,:dynamic => false, :use_name => false, :order => 5})
}

defApplication('MF-Linux-File-Receiver-App', 'lnx-file-recvr-app') {|app|
    app.shortDescription = "MF linux file receiver application"
    app.path = "/usr/local/mobilityfirst/bin/receiver-1" 
    app.defProperty('my_GUID', 'my own GUID', nil,{:type => :integer,:dynamic => false, :use_name => false, :order => 1})
}

defApplication('MF-Linux-File-Sender-App', 'lnx-file-sendr-app') {|app|
    app.shortDescription = "MF linux file sender application"
    app.path = "/usr/local/mobilityfirst/bin/sender-l" 
    app.defProperty('file', 'full path of file to send', nil,{:type => :string,:dynamic => false, :use_name => false, :order => 1})
    app.defProperty('dst_GUID', 'destination GUID', nil,{:type => :integer,:dynamic => false, :use_name => false, :order => 2})
    app.defProperty('my_GUID', 'my own GUID', nil,{:type => :integer,:dynamic => false, :use_name => false, :order => 3})
}

num_routers = 7
num_clients = 2

#baseTopo = Topology['system:topo:active']
#defTopology('static_universe', [[1,1..7]])
#defTopology('static_universe', [[1,1]])
#defTopology('universe', [[1,1],[1,2],[1,20],[16,4],[16,5],[20,1],[20,19],[20,20],[3,3],[3,8],[13,8],[13,13],[5,5],[16,6]])
defTopology('universe', 'node1-1.grid.orbit-lab.org,node1-2.grid.orbit-lab.org,node1-20.grid.orbit-lab.org,node16-5.grid.orbit-lab.org,node20-1.grid.orbit-lab.org,node20-19.grid.orbit-lab.org,node20-20.grid.orbit-lab.org,node3-3.grid.orbit-lab.org,node18-3.grid.orbit-lab.org,node13-8.grid.orbit-lab.org,node18-18.grid.orbit-lab.org,node5-5.grid.orbit-lab.org,node16-16.grid.orbit-lab.org')
allTopo = Topology['universe']

#static topo for the grid
#defTopology('router_universe', [[1,1],[1,2],[1,20],[16,4],[16,5],[20,1],[20,19],[20,20]])
defTopology('router_universe', 'node1-1.grid.orbit-lab.org,node1-2.grid.orbit-lab.org,node1-20.grid.orbit-lab.org,node16-5.grid.orbit-lab.org,node5-5.grid.orbit-lab.org,node20-19.grid.orbit-lab.org,node20-20.grid.orbit-lab.org')
routersTopo = Topology['router_universe']
routers=['node1-1.grid.orbit-lab.org','node1-2.grid.orbit-lab.org','node1-20.grid.orbit-lab.org','node16-5.grid.orbit-lab.org','node5-5.grid.orbit-lab.org','node20-19.grid.orbit-lab.org','node20-20.grid.orbit-lab.org']

#Access Routers that have both wimax and wifi interfaces
defTopology('access_universe', 'node3-3.grid.orbit-lab.org,node18-3.grid.orbit-lab.org,node13-8.grid.orbit-lab.org,node18-18.grid.orbit-lab.org')
accessTopo = Topology['access_universe']
bridges=['node3-3.grid.orbit-lab.org','node18-3.grid.orbit-lab.org','node13-8.grid.orbit-lab.org','node18-18.grid.orbit-lab.org']

#Clients that have both wimax and wifi interfaces
defTopology('client_universe', 'node20-1.grid.orbit-lab.org,node16-16.grid.orbit-lab.org')
clientsTopo = Topology['client_universe']
clients=['node20-1.grid.orbit-lab.org','node16-16.grid.orbit-lab.org']

client_guids = Array[101, 201]
#ips required for tunneling/bridging encapsulation
client_wifi_ips = Array['192.168.1.101', '192.168.1.201']
client_wimax_ips = Array['10.41.120.101', '10.41.116.116']

bridgecmds = Array[
# client 1 [20,1] - wifi bridge [3,3] - firsthop [1,1]
'/usr/local/mobilityfirst/scripts/init_bridge.sh 101 gec-12.tp 192.168.1.101 00:60:b3:25:bf:e9 wlan0 192.168.1.102 255.255.255.0 eth0 00:1b:21:7d:24:f5',
# client 1 [20,1] - wimax bridge [18,3] - firsthop [1,2]
'/usr/local/mobilityfirst/scripts/init_bridge.sh 101 gec-12.tp 10.41.120.101 00:1d:e1:36:ff:72 wmx0 10.41.118.103 255.255.0.0 eth0 00:03:1d:09:56:f7',
# client 2 [16,16] - wifi bridge [13,8] - firsthop [20,19]
'/usr/local/mobilityfirst/scripts/init_bridge.sh 201 gec-12.tp 192.168.1.201 00:60:b3:ac:2c:0a wlan0 192.168.1.202 255.255.255.0 eth0 00:03:1d:09:56:8f',
# client 2 [16,16] - wimax bridge [18,18] - firsthop [20,20]
'/usr/local/mobilityfirst/scripts/init_bridge.sh 201 gec-12.tp 10.41.116.116 00:1d:e1:3b:59:ac wmx0 10.41.118.118 255.255.0.0 eth0 00:1b:21:7d:29:53'
]

#GUID-based topology/connectivity graph for enforcement within Click
mf_topo_name = 'gec-12.tp'
#interface Click router listens on
click_dev = 'eth0'
#interface gnrs listens on
gnrs_dev = 'eth0'
#Static server participation list for GNRS service plane
srvrs_file = 'gnrs-servers-gec12-grid.lst'

#application config
file_to_send='/usr/local/mobilityfirst/data/testfile-24MB.3gp'
sender_GUID=1001
recvr_GUID=2001

for i in 1..num_routers
	defTopology("mf:topo:router_#{i}") { |t|
		aNode = routersTopo.getNodeByIndex(i-1)
		t.addNode(aNode)
		#t.addNode(routers[i-1][0], routers[i-1][1])
		print "Adding node: ", aNode, " to router topo as router with GUID: #{i}\n"
		#print "Adding node: [#{routers[i-1][0]},#{routers[i-1][1]}] as router with GUID: #{i}\n"
	}
    
	defGroup("router_#{i}", "mf:topo:router_#{i}") {|node|
		node.addApplication('MF-Router') {|app|
		    app.setProperty('type', 2)
		    app.setProperty('my_GUID', i)
		    app.setProperty('topo_URL', mf_topo_name)
		    app.setProperty('dev', click_dev)
		}
		node.addApplication('MF-GNRS') {|app|
		    app.setProperty('config_file', '/usr/local/mobilityfirst/conf/gnrsd-gec12.conf')
		    app.setProperty('self_ip', "192.168.1.#{i}")
		    app.setProperty('dev', gnrs_dev)
		    app.setProperty('srvrs_file', srvrs_file)
		}
	}
end
#Add clients and Access bridges

for i in 1..num_clients
	defTopology("mf:topo:client_#{i}") { |t|
		aNode = clientsTopo.getNodeByIndex(i-1)
		t.addNode(aNode)
		#t.addNode(clients[i-1][0], clients[i-1][1])
		print "Adding node: ", aNode, " as client\n"
		#print "Adding node: [#{clients[i-1][0]},#{clients[i-1][1]}] as client\n"
	}
	#wifi bridge
	defTopology("mf:topo:access_brdg_#{(2*i-1)}") { |t|
		aNode = accessTopo.getNodeByIndex(2*i-2)
		t.addNode(aNode)
		#t.addNode(bridges[2*i-2][0], bridges[2*i-2][1])
		print "Adding node: ", aNode, " as wifi bridge\n"
		#print "Adding node: [#{bridges[2*i-2][0]},#{bridges[2*i-2][1]}] as wifi bridge for client at [#{clients[i-1][0]},#{clients[i-1][1]}]\n"
	}
	#wimax bridge
	defTopology("mf:topo:access_brdg_#{(2*i)}") { |t|
		aNode = accessTopo.getNodeByIndex(2*i-1)
		t.addNode(aNode)
		#t.addNode(bridges[2*i-1][0], bridges[2*i-1][1])
		print "Adding node: ", aNode, " as wimax bridge\n"
		#print "Adding node: [#{bridges[2*i-1][0]},#{bridges[2*i-1][1]}] as wimax bridge for client at [#{clients[i-1][0]},#{clients[i-1][1]}]\n"
	}
    
	defGroup("client_#{i}", "mf:topo:client_#{i}") {|node|
		node.addApplication('MF-Linux-Client-Stack') {|app|
		    app.setProperty('my_GUID', client_guids[i-1])
		    app.setProperty('ifs_file', "interfaces-client#{i}-gec12-grid.xml")
		    app.setProperty('policy_file', "policy-client#{i}-gec12-grid.xml")
		    app.setProperty('wifi_ip', client_wifi_ips[i-1])
		    app.setProperty('wimax_ip', client_wimax_ips[i-1])
		}
	}
	#wifi bridge
	defGroup("access_brdg_#{(2*i-1)}", "mf:topo:access_brdg_#{(2*i-1)}") {|node|
		node.addApplication('Access-Bridge') {|app|
		    app.setProperty('cmd', bridgecmds[2*i-2])
		}
	}
	#wimax bridge
	defGroup("access_brdg_#{(2*i)}", "mf:topo:access_brdg_#{(2*i)}") {|node|
		node.addApplication('Access-Bridge') {|app|
		    app.setProperty('cmd', bridgecmds[2*i-1])
		}
	}
	if i == 1 then
		#configure sender 
		defGroup("sender_app", "mf:topo:client_#{i}") {|node|
			node.addApplication('MF-Linux-File-Sender-App') {|app|
			    app.setProperty('file', file_to_send)
			    app.setProperty('dst_GUID', recvr_GUID)
			    app.setProperty('my_GUID', sender_GUID)
			}
		}
	else
		#configure receiver
		defGroup("recvr_app", "mf:topo:client_#{i}") {|node|
			node.addApplication('MF-Linux-File-Receiver-App') {|app|
			    app.setProperty('my_GUID', recvr_GUID)
			}
		}
	end	
end

onEvent(:ALL_UP) do |event|

    #perform clean up of any prior execution - processes and state
    for i in 1..num_routers
	#click router cleanup 
	group("router_#{i}").exec("/usr/local/mobilityfirst/scripts/cleanup_click.sh 1>&2")
	#gnrsd cleanup 
	group("router_#{i}").exec("/usr/local/mobilityfirst/scripts/cleanup_gnrsd.sh 1>&2")
    end
    for i in 1..num_clients
	#access bridges cleanup
	group("access_brdg_#{i}").exec("/usr/local/mobilityfirst/scripts/cleanup_click.sh 1>&2")
	#client cleanup 
	group("client_#{i}").exec("/usr/local/mobilityfirst/scripts/cleanup_client.sh 1>&2")
    end
    wait 10
    
    # bring up the routers (along with gnrs servers)
    print "Bringing up routers...\n"
    for i in 1..num_routers
	group("router_#{i}").startApplications
    end
    wait 10

    print "Bringing up access bridges...\n"
    # bring up the access bridges (along with gnrs servers)
    for i in 1..(num_clients*2)
	group("access_brdg_#{i}").startApplications
    end
    wait 10

    print "Bringing up client stacks...\n"
    #EVENT-1: bring up the clients stacks
    #GNRS is updated with clients host GUIDs and interfaces as configured
    for i in 1..num_clients
	group("client_#{i}").startApplications
    end
    wait 10


#    wait 120
    #EVENT-2: bring up the file sender, and receiver applications
    print "Bringing up Receiver App...\n"
    group("recvr_app").startApplications
    wait 30
    print "Bringing up Sender App...\n"
    group("sender_app").startApplications

    wait 30
    #EVENT-3: Receiver starts to receive on configured interfaces

    #EVENT-4: Bring down/degrade 1 access connection to receiver 
    #File chunks continue to be sent, but are stored at intermediate routers, or redirected to good path/interface
    print "Receiver client disconnecting on Wifi...\n"
    group("access_brdg_3").exec("/usr/local/mobilityfirst/scripts/cleanup_click.sh 1>&2")
    wait 60

    #EVENT-5: Bring up access connection to receiver 
    #File chunks delivered on all available paths
    print "Receiver client re-connecting on Wifi...\n"
    group("access_brdg_3").startApplications

    #wait for experiment duration
    wait 60
    Experiment.done
end
