#
# Copyright (c) 2006-2010 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2010 WINLAB, Rutgers University, USA
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#

# This is an OMF Definition for the existing application called 'otg2'
# This definition will allow OMF entities to use and instrument this application
#
defApplication('test:app:otg2', 'otg2') do |a|

  a.path = "/usr/bin/otg2"
  a.version(1, 1, 3)
  a.shortDescription = "Programmable traffic generator v2"
  a.description = <<TEXT
OTG is a configurable traffic generator. It contains generators
producing various forms of packet streams and port for sending
these packets via various transports, such as TCP and UDP.
This version 2 is compatible with OMLv2
TEXT

  # Define the properties that can be configured for this application
  # 
  # syntax: defProperty(name = :mandatory, description = nil, parameter = nil, options = {})
  #
  a.defProperty('generator', 'Type of packet generator to use (cbr or expo)', '-g', {:type => :string, :dynamic => false})
  a.defProperty('udp:broadcast', 'Broadcast', '--udp:broadcast', {:type => :integer, :dynamic => false})
  a.defProperty('udp:dst_host', 'IP address of the Destination', '--udp:dst_host', {:type => :string, :dynamic => false})
  a.defProperty('udp:dst_port', 'Destination Port to send to', '--udp:dst_port', {:type => :integer, :dynamic => false})
  a.defProperty('udp:local_host', 'IP address of this Source node', '--udp:local_host', {:type => :string, :dynamic => false})
  a.defProperty('udp:local_port', 'Local Port of this source node', '--udp:local_port', {:type => :integer, :dynamic => false})
  a.defProperty("cbr:size", "Size of packet [bytes]", '--cbr:size', {:dynamic => true, :type => :integer})
  a.defProperty("cbr:rate", "Data rate of the flow [kbps]", '--cbr:rate', {:dynamic => true, :type => :integer})
  a.defProperty("exp:size", "Size of packet [bytes]", '--exp:size', {:dynamic => true, :type => :integer})
  a.defProperty("exp:rate", "Data rate of the flow [kbps]", '--exp:rate', {:dynamic => true, :type => :integer})
  a.defProperty("exp:ontime", "Average length of burst [msec]", '--exp:ontime', {:dynamic => true, :type => :integer})
  a.defProperty("exp:offtime", "Average length of idle time [msec]", '--exp:offtime', {:dynamic => true, :type => :integer})

  # Define the Measurement Points and associated metrics that are available for this application
  #
  a.defMeasurement('udp_out') do |m|
    m.defMetric('ts',:float)
    m.defMetric('flow_id',:long)
    m.defMetric('seq_no',:long)
    m.defMetric('pkt_length',:long)
    m.defMetric('dst_host',:string)
    m.defMetric('dst_port',:long)
  end
end
