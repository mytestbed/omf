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

# Define a prototype
#
defPrototype("test:proto:iperftcpreceiver") { |p|
  p.name = "Iperf TCP Receiver"
  p.description = "Nodes which receive packets"

  # Define the properties (and their default values) that can be configured 
  # for this prototype
  #
  p.defProperty('server', 'Client/Server', true)
  p.defProperty('port', 'Port to listen on', 5001)
  p.defProperty('time', 'Duration of experiment (seconds)', 10)
  p.defProperty('window', 'Receiver Window Size', 64000)
  p.defProperty('report_interval', 'Interval beween reports', 1)

  # Define the application to be installed on this type of node,
  # bind the application properties to the prototype properties,
  # and finally, define what measurements should be collected
  # for each application.
  #
  p.addApplication("test:app:iperf"){|iperf|
    iperf.bindProperty('server')
    iperf.bindProperty('port','port')
    iperf.bindProperty('time')
    iperf.bindProperty('window')
    iperf.bindProperty('interval', 'report_interval')
    iperf.measure('Peer_Info', :samples => 1)
    iperf.measure('TCP_Info', :samples =>1)
  }
}
