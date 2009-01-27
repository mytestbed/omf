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
require 'handler/appDefinition'

defApplication('test:app:otr', 'otr') { |a|

  a.version(1, 1, 2)
  a.shortDescription = "Programmable traffic generator"
  a.description = <<TEXT
otr is a configurable traffic sink. It contains port to receive
packet streams via various transport options, such as TCP and UDP.
TEXT

  #defProperty(name, description, mnemonic = nil, options = nil)
  a.defProperty('protocol', 'Protocol to use [udp|tcp]', nil, {:type => :string, :dynamic => false})
  a.defProperty('hostname', 'My own ID', nil, {:type => :string, :dynamic => false})
  a.defProperty('port', 'transport port number of listen on', nil, {:type => :integer, :dynamic => false})
  a.defProperty('rxdev', 'Device Name of local host to receive',nil, {:type => :string, :dynamic => false})
  a.defProperty('dstfilter','filter packets with IP destination address',nil, {:type => :string, :dynamic => false})

  a.defMeasurement("receiverport") { |m|
    m.defMetric('pkt_seqno', 'long', 'Packet sequence id of the stream')
    m.defMetric('flow_no', 'int','id of receiving flow')
    m.defMetric('rcvd_pkt_size', 'long', 'Payload size')
    m.defMetric('rx_timestamp', 'long', 'Time when packet has been received')
    m.defMetric('rssi', 'int', 'rssi of received packet')
    m.defMetric('xmitrate','int','channel rate of received packet')
    m.defMetric('hw_timestamp','int','Hw timestamp of incoming packet')
  }

  a.defMeasurement("flow") { |m|
    m.defMetric('flow_no', 'int', 'id of the flow')
    m.defMetric('sender_port', 'int', 'port number of sender socket')
  }

  a.path = "/usr/bin/otr"
}

if $0 == __FILE__
  require 'handler/appDefinition'
  require 'stringio'
  require 'rexml/document'
  include REXML

  sio = StringIO.new()
  a = AppDefinition['test:app:otr']
  a.to_xml.write(sio, 2)
  sio.rewind
  puts sio.read
  sio.rewind
  doc = Document.new(sio)
  t = AppDefinition.from_xml(doc.root)
  puts
  puts "-------------------------"
  puts
  t.to_xml.write($stdout, 2)
end
