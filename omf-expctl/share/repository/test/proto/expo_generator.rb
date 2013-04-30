defPrototype("test:proto:expo_generator") do |proto|
  proto.name = "UDP_EXPO_Traffic_Generator"
  proto.description = "A traffic generator using an Exponential model"

  proto.defProperty('trafficModel', 'Model of traffic to use', 'expo')
  proto.defProperty('destinationHost', 'Host to send packets to')
  proto.defProperty('destinationPort', 'Host to send packets to',3000)
  proto.defProperty('localHost', 'Host that generate the packets')
  proto.defProperty('localPort', 'Host that generate the packets',3000)
  proto.defProperty('packetSize', 'Size of packets [bytes]', 512)
  proto.defProperty('rate', 'Number of bits per second [kbps]', 1024)
  proto.defProperty('burstDuration', 'Average burst duration [msec]', 10)
  proto.defProperty('idleDuration', 'Average idle duration [msec]', 50)
  proto.defProperty('broadcast', 'Allow broadcast', 1)

  proto.addApplication("test:app:otg2") do |app|
    app.bindProperty('generator', 'trafficModel')	
    app.bindProperty('udp:broadcast', 'broadcast')	
    app.bindProperty('udp:dst_host', 'destinationHost')
    app.bindProperty('udp:dst_port', 'destinationPort')
    app.bindProperty('udp:local_host', 'localHost')
    app.bindProperty('udp:local_port', 'localPort')
    app.bindProperty('exp:size', 'packetSize')
    app.bindProperty('exp:rate', 'rate')
    app.bindProperty('exp:ontime', 'burstDuration')
    app.bindProperty('exp:offtime', 'idleDuration')
    app.measure('udp_out', :samples => 1) do |mp|
      mp.filter('seq_no','first')
      mp.filter('pkt_length','first')
    end
  end
end
