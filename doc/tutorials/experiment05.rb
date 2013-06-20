#Welcome to Experiment 05
#This ED will allow the experimenter to install a 3rd party application on specified nodes
#The otg2 application will be used as an example in this ED

#Section 1
#Define the file path of application
#Define experiment parameters and measurement points

defApplication('otg2') do |app|
    
    app.binary_path = "/usr/bin/otg2"
    app.appPackage = "http://extant.me/dev/path/to/archive.tar"
    app.description = "Programmable traffic generator v2"
    app.description = "OTG is a configurable traffic generator."
    
    # Define the properties that can be configured for this application
    # syntax: defProperty(name = :mandatory, description = nil, parameter = nil, options = {})
    app.defProperty('generator', 'Type of packet generator to use (cbr or expo)', '-g', {:type => :string, :dynamic => false})
    app.defProperty('udp:broadcast', 'Broadcast', '--udp:broadcast', {:type => :integer, :dynamic => false})
    app.defProperty('udp:dst_host', 'IP address of the Destination', '--udp:dst_host', {:type => :string, :dynamic => false})
    app.defProperty('udp:dst_port', 'Destination Port to send to', '--udp:dst_port', {:type => :integer, :dynamic => false})
    app.defProperty('udp:local_host', 'IP address of this Source node', '--udp:local_host', {:type => :string, :dynamic => false})
    app.defProperty('udp:local_port', 'Local Port of this source node', '--udp:local_port', {:type => :integer, :dynamic => false})
    app.defProperty("cbr:size", "Size of packet [bytes]", '--cbr:size', {:dynamic => true, :type => :integer})
    app.defProperty("cbr:rate", "Data rate of the flow [kbps]", '--cbr:rate', {:dynamic => true, :type => :integer})
    app.defProperty("exp:size", "Size of packet [bytes]", '--exp:size', {:dynamic => true, :type => :integer})
    app.defProperty("exp:rate", "Data rate of the flow [kbps]", '--exp:rate', {:dynamic => true, :type => :integer})
    app.defProperty("exp:ontime", "Average length of burst [msec]", '--exp:ontime', {:dynamic => true, :type => :integer})
    app.defProperty("exp:offtime", "Average length of idle time [msec]", '--exp:offtime', {:dynamic => true, :type => :integer})
    
    # Define the Measurement Points and associated metrics that are available for this application
    app.defMeasurement('udp_out') do |m|
        m.defMetric('ts',:float)
        m.defMetric('flow_id',:long)
        m.defMetric('seq_no',:long)
        m.defMetric('pkt_length',:long)
        m.defMetric('dst_host',:string)
        m.defMetric('dst_port',:long)
    end
end
