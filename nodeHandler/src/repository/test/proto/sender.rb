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
# Define a prototype containing a single
# traffic generator (otg).
#


defPrototype("test:proto:sender") { |p|
  p.name = "Sender"
  p.description = "A node which transmit a stream of packets"
  # List properties of prototype
  p.defProperty('protocol', 'Protocol to use', 'udp')
  p.defProperty('generator', 'Generator to use', 'cbr')
  p.defProperty('destinationHost', 'Host to send packets to')
  p.defProperty('packetSize', 'Size of packets', 1000)
  p.defProperty('rate', 'Number of bits per second', 1000)
  p.defProperty('broadcast','broadcast or not', 'off')
  p.defProperty('port','local port to bind to', 3000)

  # Define applications to be installed on this type of node,
  # bind the application properties to the prototype properties,
  # and finally, define what measurements should be collected
  # for each application.
  #
  p.addApplication(:otg, "test:app:otg") {|otg|
    otg.bindProperty('protocol')
    otg.bindProperty('generator')
    otg.bindProperty('dsthostname', 'destinationHost')
    otg.bindProperty('size', 'packetSize')
    otg.bindProperty('rate')
    otg.bindProperty('broadcast')
    otg.bindProperty('port')

    otg.measure('senderport') {|m|
      m.useTimeFilter(1)
      m.add('pkt_seqno')
      m.add('pkt_size', Filter::SUM)
      m.add('gen_timestamp')
      m.add('tx_timestamp')
    }
  }
}

if $0 == __FILE__
  p.to_xml.write($stdout, 2)
  puts
end
