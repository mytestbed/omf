defPrototype("test:proto:cbr_generator") do |proto|
  proto.name = "UDP_CBR_Traffic_Generator"
  proto.description = "A traffic generator using a Constant Bit Rate model"

  proto.defProperty('trafficModel', 'Model of traffic to use', 'cbr')
  proto.defProperty('destinationHost', 'Host to send packets to')
  proto.defProperty('destinationPort', 'Host to send packets to',3000)
  proto.defProperty('localHost', 'Host that generate the packets')
  proto.defProperty('localPort', 'Host that generate the packets',3000)
  proto.defProperty('packetSize', 'Size of packets [bytes]', 512)
  proto.defProperty('rate', 'Number of bits per second [kbps]', 1024)
  proto.defProperty('broadcast', 'Allow broadcast', 1)

  proto.addApplication("test:app:otg2") do |app|
    app.bindProperty('generator', 'trafficModel')	
    app.bindProperty('udp:broadcast', 'broadcast')	
    app.bindProperty('udp:dst_host', 'destinationHost')
    app.bindProperty('udp:dst_port', 'destinationPort')
    app.bindProperty('udp:local_host', 'localHost')
    app.bindProperty('udp:local_port', 'localPort')
    app.bindProperty('cbr:size', 'packetSize')
    app.bindProperty('cbr:rate', 'rate')
    app.measure('udp_out', :samples => 1) do |mp|
      mp.filter('seq_no','first')
      mp.filter('pkt_length','first')
    end
  end
end
