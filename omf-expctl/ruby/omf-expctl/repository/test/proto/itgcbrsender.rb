#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
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
require 'omf-expctl/prototype'
require 'omf-expctl/filter'
require 'omf-expctl/appDefinition'

p = Prototype.create("test:proto:itgcbrsender")
p.name = "ITG Sender"
p.description = "Nodes which send a stream of packets"
p.defProperty('meter', 'one way delay or RTT', 'owdm')
p.defProperty('protocol', 'Protocol to use', 'udp')
p.defProperty('destinationHost', 'Host to send packets to')
#p.defProperty('sender_port', 'Host to send packets to')
p.defProperty('constsize', 'Size of packets', 1000)
p.defProperty('constrate', 'Number of bits per second', 1000)
p.defProperty('duration', 'Time for sending (millisec)', 1000)
p.defProperty('gen_delay', 'Generation delay (millisec)', 10000)
#p.defProperty('recv_logfile', 'Recv log')
p.defProperty('recv_port', 'Receiver_port', 8000)

itgs = p.addApplication(:itgs, "test:app:itgs")
itgs.bindProperty('m','meter')
itgs.bindProperty('T','protocol')
itgs.bindProperty('a', 'destinationHost')
itgs.bindProperty('c', 'constsize')
itgs.bindProperty('C', 'constrate')
itgs.bindProperty('t', 'duration')
itgs.bindProperty('d', 'gen_delay')
#itgs.bindProperty('l', 'logfile')
#itgs.bindProperty('x', 'recv_logfile')
itgs.bindProperty('r', 'recv_port')

itgs.addMeasurement('senderport',  Filter::TIME,
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

