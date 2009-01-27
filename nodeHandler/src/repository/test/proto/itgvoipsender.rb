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
# Define a prototype
#

require 'handler/prototype'
require 'handler/filter'
require 'handler/appDefinition'

p = Prototype.create("test:proto:itgvoipsender")
p.name = "ITG VoIP Sender"
p.description = "Nodes which send a stream of packets"
p.defProperty('meter', 'one way delay or RTT', 'owdm')
p.defProperty('duration', 'Time for sending (millisec)', 1000)
p.defProperty('protocol',' UDP or UDP_Libmac')
p.defProperty('recv_port', 'Receiver_port', 8000)
p.defProperty('codec', 'VoIP codec')
p.defProperty('voip_control', 'VoIP control')
p.defProperty('destinationHost', 'Host to send packets to')

itgs = p.addApplication(:itgs, "test:app:itgs")
itgs.bindProperty('t', 'duration')
itgs.bindProperty('codec')
itgs.bindProperty('T','protocol')
itgs.bindProperty('voip_control')
itgs.bindProperty('a', 'destinationHost')
itgs.bindProperty('m','meter')
itgs.bindProperty('r', 'recv_port')

itgs.addMeasurement('senderport',  Filter::SAMPLE,
  {Filter::SAMPLE_SIZE => 1},
  [
    ['stream_no'],
    ['pkt_seqno'],
    ['pkt_size', Filter::SUM],
    ['gen_timestamp'],
    ['tx_timestamp']
  ]
)

if $0 == __FILE__
  p.to_xml.write($stdout, 2)
  puts
end

