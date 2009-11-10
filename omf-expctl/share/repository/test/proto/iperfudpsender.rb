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
defPrototype("test:proto:iperfudpsender") { |p|
p.name = "Iperf UDP Sender"
p.description = "Nodes which send a stream of packets"
p.defProperty('use_udp', 'Protocol to use', false)
p.defProperty('client', 'Host to send packets to', "localhost")
p.defProperty('sender_rate', 'Number of bits per second', 100000000)
p.defProperty('port', 'Port to send packets to', 5001)
#p.defProperty('len', 'Size of packets')
p.defProperty('time', 'Experiment duration (sec)', 10)

p.addApplication("test:app:iperfs"){|iperfs|
iperfs.bindProperty('Audp','use_udp')
iperfs.bindProperty('Aclient', 'client')
iperfs.bindProperty('bandwidth','sender_rate')
#iperfs.bindProperty('len')
iperfs.bindProperty('time')
iperfs.bindProperty('port')
iperfs.measure('Peer_Info', :samples => 1)
iperfs.measure('TCP_received', :samples =>1)
iperfs.measure('UDP_received', :samples =>1)
}
if $0 == __FILE__
  p.to_xml.write($stdout, 2)
  puts
end
}

