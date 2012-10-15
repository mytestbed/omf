defApplication('test:app:trace_oml2', 'trace_oml2'){|a|

a.path = "/usr/bin/trace_oml2"
 a.defProperty('interface', 'interface to listen to', '-i')
 a.defProperty('radiotap', 'Radiotap metadata enable', '-r', {:dynamic => false, :type => :boolean})
 a.defProperty('filter', 'some filers for this tap following libpcap syntax', '-f')

 a.defMeasurement("radiotap") do |m|
 m.defMetric('tsft', :long)
 m.defMetric('rate', :long)
 m.defMetric('freq', :long)
 m.defMetric('sig_strength_dBm', :long)
 m.defMetric('noise_strength_dBm', :long)
 m.defMetric('sig_strength', :long)
 m.defMetric('noise_strength', :long)
 m.defMetric('attenuation', :long)
 m.defMetric('attenuation_dB', :long)
 m.defMetric('power', :long)
 m.defMetric('antenna', :long)
 m.defMetric('data_retries', :long)
 m.defMetric('sourceMAC', :string)
 m.defMetric('dstMAC', :string)
end

 a.defMeasurement("ip") do |m|
 m.defMetric('ip_tos', :long)
 m.defMetric('ip_len', :long)
 m.defMetric('ip_id', :long)
 m.defMetric('ip_off', :long)
 m.defMetric('ip_ttl', :long)
 m.defMetric('ip_proto', :long)
 m.defMetric('ip_sum', :long)
 m.defMetric('ip_src', :string)
 m.defMetric('ip_dst', :string)
m.defMetric('ip_sizeofpacket', :long)
 end

 a.defMeasurement("tcp") do |m|
 m.defMetric('tcp_source', :long)
 m.defMetric('tcp_dest', :long)
 m.defMetric('tcp_seq', :long)
 m.defMetric('tcp_ack_seq', :long)
 m.defMetric('tcp_window', :long)
 m.defMetric('tcp_checksum', :long)
 m.defMetric('tcp_urgptr', :long)
 m.defMetric('tcp_packet_size', :long)
 end

 a.defMeasurement("udp") do |m|
 m.defMetric('udp_source', :long)
 m.defMetric('udp_dest', :long)
 m.defMetric('udp_len', :long)
 m.defMetric('udp_checksum', :long)
 end

 a.defMeasurement("sensor") do |m|
 m.defMetric('val', :long)
 m.defMetric('inverse', :float)
 m.defMetric('name', :string)
 end

}
