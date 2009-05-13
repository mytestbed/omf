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
# $Id: forwarder.rb 997 2006-01-20 06:59:31Z sachin $

require 'omf-expctl/prototype'
require 'omf-expctl/filter'
require 'omf-expctl/appDefinition'

p = Prototype.create("test:proto:forwarder")
p.name = "Forwarder"
p.description = "Nodes which forward packets"
p.defProperty('protocol', 'Protocol to use', 'raw')
p.defProperty('rxdev', 'hw interface to listen on', 'eth0')
p.defProperty('txdev', 'hw interaface to send', 'eth0')
p.defProperty('ipFilter', 'IP address of the destination', '12.0.0.6')
p.defProperty('nextHopMAC', 'hw address of next-hop receiver', 'FF:FF:FF:FF:FF:FF')

otf = p.addApplication('otf', "test:app:otf")

otf.bindProperty('protocol')
otf.bindProperty('rxdev')
otf.bindProperty('txdev')
otf.bindProperty('dstfilter','ipFilter')
otf.bindProperty('dstmacaddr','nextHopMAC')

otf.addMeasurement('senderport',  Filter::TIME,
  {Filter::SAMPLE_SIZE => 1},
  [
    ['stream_no'],
    ['pkt_seqno'],
    ['pkt_size', Filter::SUM],
    ['gen_timestamp'],
    ['tx_timestamp']
  ]
)
otf.addMeasurement('otfreceiver',  Filter::TIME,
  {Filter::SAMPLE_SIZE => 1},
  [
    ['flow_no'],
    ['pkt_num_rcvd'],
    ['rcvd_pkt_size', Filter::SUM],
    ['rx_timestamp',  Filter::MEAN],
    ['rssi', Filter::MEAN],
    ['xmitrate']
  ]
)

if $0 == __FILE__
  p.to_xml.write($stdout, 2)
  puts
end

