#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2008 WINLAB, Rutgers University, USA
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
#
# Create an application representation from scratch
#
defApplication('test:app:iperf','iperf'){|a|
  a.name = "iperf"
  a.version(0, 0, 1)
  a.path = "/usr/bin/iperf_oml2"
  a.shortDescription = "Iperf traffic generator"
  a.description = <<TEXT
Iperf is a traffic generator for TCP and UDP traffic. It contains generators
producing various forms of packet streams and port for sending
these packets via various transports, such as TCP and UDP.
TEXT

  # Define the properties that can be configured for this application
  # 
  # syntax: defProperty(name, description, mnemonic = nil, options = nil)
  #
  a.defProperty('udp', 'Use UDP, otherwise TCP by default', 'u',  {:order => 2, :dynamic => false, :type => :boolean})
  a.defProperty('client', 'Run as client', 'c',  {:order => 1, :dynamic => false, :type => :string})
  a.defProperty('server', 'Client/Server', 's', {:type => :boolean, :dynamic => false})
  a.defProperty('port', 'Sender port number', 'p', {:type => :integer, :dynamic => false})
  a.defProperty('window', 'TCP Send Window Size', nil, {:type => :integer, :dynamic => false})
  a.defProperty('time', "Duration of traffic generation(secs)", nil, {:type => :integer, :dynamice => false})
  a.defProperty('bandwidth', "Offered load for UDP", 'b',  {:dynamic => false, :type => :integer})
  a.defProperty('parallel', "Number of parallel flows", nil, {:type => :integer, :dynamic => false})
  a.defProperty('interval', "Interval between reports (sec)", nil, {:type => :integer, :dynamic => false})

  # Define the Measurement Points and associated metrics that are available for this application
  #
  a.defMeasurement("TCP_Info"){ |m|
    m.defMetric('ID', :long)
    m.defMetric('Begin_interval', :float)
    m.defMetric('End_interval', :float)
    m.defMetric('Transfer', :float)
    m.defMetric('Bandwidth', :float)
 }
  a.defMeasurement("UDP_Periodic_Info"){ |m|
    m.defMetric('ID', :long)
    m.defMetric('Begin_interval', :float)
    m.defMetric('End_interval', :float)
    m.defMetric('Transfer', :float)
    m.defMetric('Bandwidth', :float)
 }
  a.defMeasurement("UDP_Rich_Info"){ |m|
    m.defMetric('ID', :long)
    m.defMetric('Begin_interval', :float)
    m.defMetric('End_interval', :float)
    m.defMetric('Transfer', :float)
    m.defMetric('Bandwidth', :float)
    m.defMetric('Jitter', :float)
    m.defMetric('Packet_Lost', :long)
    m.defMetric('Total_Packet', :long)
    m.defMetric('PLR', :float)
 }
  a.defMeasurement("Peer_Info"){ |m|
    m.defMetric('ID', :long)
    m.defMetric('local_address', :string)
    m.defMetric('local_port', :long)
    m.defMetric('foreign_address', :string)
    m.defMetric('foreign_port', :long)
 }
  a.omlPrefix = 'iperf'
}

