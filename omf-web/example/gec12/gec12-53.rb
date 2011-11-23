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

defApplication('Configure-Bridge') do |app|
  app.shortDescription = "Access Bridge for wireless client"
  app.path '/usr/local/mobilityfirst/scripts/init_bridge.sh'
  app.defProperty 'guid', 'GUID of ??', nil, :order => 1, :use_name => false
  app.defProperty '???', '', nil, :order => 2, :default => 'gec-12.tp', :use_name => false
  app.defProperty 'localIPAddr', 'IP of ??', nil, :order => 1, :use_name => false
  app.defProperty 'localMAC', 'MAC of ??', nil, :order => 1, :use_name => false
  app.defProperty 'localIF', 'IF name of ??', nil, :order => 1, :use_name => false
  app.defProperty 'remoteIPAddr', 'IP of ??', nil, :order => 1, :use_name => false  
  app.defProperty 'remoteNetmask', 'IP of ??', nil, :order => 1, :use_name => false    
  app.defProperty 'remoteIF', 'IP of ??', nil, :order => 1, :use_name => false  
  app.defProperty 'remoteMAC', 'IP of ??', nil, :order => 1, :use_name => false    
end

###################

mf_topo_name = 'gec-12.tp'

#interface Click router listens on
click_dev = 'eth0'

#interface gnrs listens on
gnrs_dev = 'eth0'

#Static server participation list for GNRS service plane
srvrs_file = 'gnrs-servers-gec12-grid.lst'

#application config
file_to_send = '/usr/local/mobilityfirst/data/testfile-24MB.3gp'
sender_GUID = 1001
recvr_GUID = 2001


Components = {
  :routers => [ 
    1 => ['node1-1'],
    2 => ['node1-2'],
    3 => ['node1-20']
  ],
  :access => [
    
  ]
}

bridges=['node3-3.grid.orbit-lab.org','node18-3.grid.orbit-lab.org','node13-8.grid.orbit-lab.org','node18-18.grid.orbit-lab.org']
clients=['node20-1.grid.orbit-lab.org','node16-16.grid.orbit-lab.org']

defTopology('universe') do |t|
    ['node1-1', 'node1-2', 'node1-20', 'node16-5', 'node5-5', 'node20-19', 'node20-20'].each_with_index do |n, i|
      props = {:guid => i, :self_ip => "192.168.1.#{i}"}
      t.addNode n, :groups => [:routers], :alias => "hop_#{i}", :props => props
    end

    [
      # client 1 [20,1] - wifi bridge [3,3] - firsthop [1,1]
      ['node3-3', {:a => 101, :b => '192.168.1.101', :c => '00:60:b3:25:bf:e9', :d => 'wlan0', :e => '192.168.1.102', 
                    :f => '255.255.255.0', :g => 'eth0', :h => '00:1b:21:7d:24:f5'}],
      # client 1 [20,1] - wimax bridge [18,3] - firsthop [1,2]
      ['node18-3'],
      #'/usr/local/mobilityfirst/scripts/init_bridge.sh 101 gec-12.tp 10.41.120.101 00:1d:e1:36:ff:72 wmx0 10.41.118.103 255.255.0.0 eth0 00:03:1d:09:56:f7',
      # client 2 [16,16] - wifi bridge [13,8] - firsthop [20,19]
      ['node13-8'],
      #'/usr/local/mobilityfirst/scripts/init_bridge.sh 201 gec-12.tp 192.168.1.201 00:60:b3:ac:2c:0a wlan0 192.168.1.202 255.255.255.0 eth0 00:03:1d:09:56:8f',
      # client 2 [16,16] - wimax bridge [18,18] - firsthop [20,20]
      ['node18-18'],
      #'/usr/local/mobilityfirst/scripts/init_bridge.sh 201 gec-12.tp 10.41.116.116 00:1d:e1:3b:59:ac wmx0 10.41.118.118 255.255.0.0 eth0 00:1b:21:7d:29:53'
    ].each_with_index do |arr, i|
      name, props = arr
      t.addNode name, :groups => [:access_bridges], :props => (props || {})
    end

    [
      ['node20-1', {'guid' => 101, 'w0.ip' => '192.168.1.101', 'wx0.ip' => '10.41.120.101'}],
      ['node16-16', {'guid' => 201, 'w0.ip' => '192.168.1.201', 'wx0.ip' => '10.41.116, 116'}]
    ].each_with_index do |arr, i|
      name, props = arr
      props[:client_id] = 1 
      t.addNode name, :groups => [:clients, (i % 2) == 0 ? :senders : receivers], :props => props
    end

    # t.addLink 'client_1#w0', 'wifi_bridge_1#w0'
    # t.addLink 'wifi_bridge_1#e0', 'hop_1#e0'
    # t.addLink 'client_1#wx0', 'wimax_bridge_1#wx0'
    # t.addLink 'wimax_bridge_1#e0', 'hop_2#e0'
end

defGroup("routers") do |g|
  g.addNodes :topo => :universe, :group => :routers
  g.addApplication('MF-Router') do |app|
    app.setProperty('type', 2)
    app.setProperty('my_GUID', '%i')
    app.setProperty('topo_URL', mf_topo_name)
    app.setProperty('dev', click_dev)
  end
  g.addApplication('MF-GNRS') do |app|
    app.setProperty('config_file', '/usr/local/mobilityfirst/conf/gnrsd-gec12.conf')
    app.setProperty('self_ip', "%192.168.1.%i")
    app.setProperty('dev', gnrs_dev)
    app.setProperty('srvrs_file', srvrs_file)
  end
end

defGroup("clients") do |g|
  node.addApplication('MF-Linux-Client-Stack') do |app|
    app.setProperty('my_GUID', "%%guid%")
    app.setProperty('ifs_file', "%interfaces-client%client_id%-gec12-grid.xml")
    app.setProperty('policy_file', "%policy-client%client_id%-gec12-grid.xml")
    app.setProperty('wifi_ip', "%%wifi_ip%")
    app.setProperty('wimax_ip', "%%wimax_ip%")
  end
end

defGroup "access_bridges" do |g|
  g.addApplication('Access-Bridge') do |app|
    app.setProperty('cmd', bridgecmds[2*i-2])
  end
end

defGroup "senders" do |g|
  g.addApplication('MF-Linux-File-Sender-App') do |app|
    app.setProperty('file', file_to_send)
    app.setProperty('dst_GUID', recvr_GUID)
    app.setProperty('my_GUID', sender_GUID)
  end
end

defGroup 'receivers' do |g|
  g.addApplication('MF-Linux-File-Receiver-App') do |app|
    app.setProperty('my_GUID', recvr_GUID)
  end
end

onEvent(:ALL_UP) do |event|

  #click router cleanup 
	group("routers").exec("/usr/local/mobilityfirst/scripts/cleanup_click.sh 1>&2")
	#gnrsd cleanup 
	group("routers").exec("/usr/local/mobilityfirst/scripts/cleanup_gnrsd.sh 1>&2")

	#access bridges cleanup
	group("access_bridges").exec("/usr/local/mobilityfirst/scripts/cleanup_click.sh 1>&2")
	#client cleanup 
	group("client_s").exec("/usr/local/mobilityfirst/scripts/cleanup_client.sh 1>&2")
  wait 10
    
  # bring up the routers (along with gnrs servers)
  log "Bringing up routers..."
	group("routers").startApplications
  wait 10

  log "Bringing up access bridges..."
	group("access_bridges").startApplications
  wait 10

  log "Bringing up client stacks..."
  #EVENT-1: bring up the clients stacks
  #GNRS is updated with clients host GUIDs and interfaces as configured
	group("clients").startApplications
  wait 10


#    wait 120
    #EVENT-2: bring up the file sender, and receiver applications
  log "Bringing up Receiver App...\n"
  group("receivers").startApplications
  wait 30
  log "Bringing up Sender App...\n"
  group("senders").startApplications
  wait 30

    #EVENT-3: Receiver starts to receive on configured interfaces

    #EVENT-4: Bring down/degrade 1 access connection to receiver 
    #File chunks continue to be sent, but are stored at intermediate routers, or redirected to good path/interface
  log "Receiver client disconnecting on Wifi...\n"
  node("access_bridge_3").exec("/usr/local/mobilityfirst/scripts/cleanup_click.sh 1>&2")
  wait 60

  #EVENT-5: Bring up access connection to receiver 
  #File chunks delivered on all available paths
  log "Receiver client re-connecting on Wifi...\n"
  node("access_bridge_3").startApplications

  #wait for experiment duration
  wait 60
  Experiment.done
end
