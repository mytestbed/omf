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

p = Prototype.create("test:proto:iperftcpsender")
p.name = "Iperf TCP Sender"
p.description = "Nodes which send a stream of packets"
p.defProperty('client', 'Host to send packets to')
#p.defProperty('port', 'Port to send packets to')
p.defProperty('len', 'Size of packets')
p.defProperty('window', 'TCP window Size (bytes)', 64000)
p.defProperty('time', 'Experiment duration (sec)', 10)

iperfs = p.addApplication(:iperfs, "test:app:iperfs")
iperfs.bindProperty('client')
iperfs.bindProperty('len')
iperfs.bindProperty('time')
iperfs.bindProperty('window')
iperfs.measure('Peer_Info', :samples => 1)
iperfs.measure('TCP_received', :samples =>1)

#
if $0 == __FILE__
  p.to_xml.write($stdout, 2)
  puts
end
