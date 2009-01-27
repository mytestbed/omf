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

p = Prototype.create("test:proto:raw_receiver")
p.name = "RAW Receiver"
p.description = "Nodes which receive packets"
p.defProperty('protocol', 'Protocol to use', 'udp')
p.defProperty('rxdev', 'rx dev interface')
p.defProperty('dstfilter', 'dst ip address as filter')

otr= p.addApplication('otr', "test:app:otr")
otr.bindProperty('protocol')
otr.bindProperty('rxdev')
otr.bindProperty('dstfilter')

otr.addMeasurement('receiverport',Filter::TIME,
  {Filter::SAMPLE_SIZE => 1},
  [
    ['pkt_seqno'],
    ['flow_no'],
    ['rcvd_pkt_size', Filter::SUM],
    ['rx_timestamp'],
    ['rssi'],
    ['xmitrate']
  ]
 )

      otr.addMeasurement('flow', Filter::SAMPLE,
      {Filter::SAMPLE_SIZE => 1},
        [
     ['flow_no'],
           ['sender_port']
       ]
       )

   if $0 == __FILE__
           p.to_xml.write($stdout, 2)
       puts
   end
