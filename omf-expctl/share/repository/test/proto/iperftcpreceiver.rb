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

p = Prototype.create("test:proto:iperftcpreceiver")
p.name = "Iperf TCP Receiver"
p.description = "Nodes which receive packets"
p.defProperty('server', 'Client/Server')
#p.defProperty('port', 'Port to listen on')
p.defProperty('time', 'Duration of experiment (seconds)', 10)
p.defProperty('window', 'Receiver Window Size', 64000)
p.defProperty('report_interval', 'Interval beween reports', 1)


iperfr = p.addApplication('iperfr', "test:app:iperfr")
iperfr.bindProperty('server')
#iperfr.bindProperty('port','port')
iperfr.bindProperty('time')
iperfr.bindProperty('window')
iperfr.bindProperty('interval', 'report_interval')
iperfr.measure('Peer_Info', :samples => 1)
iperfr.measure('TCP_received', :samples =>1)


if $0 == __FILE__
  p.to_xml.write($stdout, 2)
  puts
end
