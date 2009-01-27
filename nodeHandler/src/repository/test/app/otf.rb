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
#$Id: otf.rb 998 2006-01-20 06:59:58Z sachin $

require 'handler/appDefinition'

a = AppDefinition.create('test:app:otf')
a.name = "otr"
a.version(0, 0, 2)
a.shortDescription = "Programmable traffic forwarder"
a.description = <<TEXT
otf is a configurable traffic forwarder. It re-route traffice from one
incoming interface to another one using raw sockets
TEXT

#addProperty(name, description, mnemonic, type, isDynamic = false, constraints = nil)
a.addProperty('protocol', 'Protocol to use [raw|raw_libmac]', nil, :string, false)
a.addProperty('rxdev', 'incoming interface [eth0|eth2|eth3]', nil, :string, false)
a.addProperty('txdev', 'outgoing interface [eth0|eth2|eth3]', nil, :string, false)
a.addProperty('dstfilter', 'packet filter using destination IP address', nil, :string, false)
a.addProperty('dstmacaddr', 'MAC address for next-hop', nil,:string, false)

a.addMeasurement("senderport", nil, [
    ['stream_no', 'int'],
    ['pkt_seqno', 'long'],
    ['pkt_size', 'long'],
    ['gen_timestamp', 'long'],
    ['tx_timestamp', 'long']
])

a.addMeasurement("otfreceiver", nil, [
  ['flow_no','int','id of receiving flow'],
  ['pkt_num_rcvd','long',' Packet Sequence id of the flow'],
  ['rcvd_pkt_size', 'long', 'Payload size'],
  ['rx_timestamp', 'long', 'Time when packet has been received'],
  ['rssi', 'int', 'rssi of received packet'] ,
  ['xmitrate','int','channel rate of received packet']
])



#a.repository("http://repository.orbit-lab.org/common/gennySender")
#a.repository("http://controlpxe.orbit-lab.org/repository/genny-0.3.tar")
#a.aptName = 'orbit-otf'

a.path = "/usr/local/bin/otf"
#a.environment['LD_LIBRARY_PATH'] = '/usr/local/lib/oml2'

if $0 == __FILE__
  require 'stringio'
  require 'rexml/document'
  include REXML

  sio = StringIO.new()
  a.to_xml.write($stdout, 2)
end
