#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
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

defPrototype("omf:proto:receiver") do |p|
  p.name = "Receiver"
  p.description = "Nodes which receive packets"

  p.defProperty('protocol', 'Protocol to use', 'udp')
  p.defProperty('port', 'Port to listen on', 4000)

  p.addApplication('otr', "omf:app:otr") do |otr|
    otr.bindProperty('protocol')
    otr.bindProperty('port')
  
    otr.measure('receiverport', :period => 1.sec) do |m|
      m.add('pkt_seqno')
      m.add('flow_no')
      m.add('rcvd_pkt_size', m.filter.SUM)
      m.add('rx_timestamp')
      m.add('rssi', m.filer.AVERAGE)
      m.add('xmitrate', m.filer.AVERAGE)
    end

    otr.measure('flow', :samples => 1)  do |m|
      m.add('flow_no')
      m.add('sender_port')
    end
  end
end

