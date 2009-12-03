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
defPrototype("test:proto:iperftcpsender") { |p|
  p.name = "Iperf TCP Sender"
  p.description = "Nodes which send a stream of packets"

  # Define the properties (and their default values) that can be configured 
  # for this prototype
  #
  p.defProperty('client', 'Host to send packets to')
  p.defProperty('len', 'Size of packets')
  p.defProperty('window', 'TCP window Size (bytes)', 64000)
  p.defProperty('time', 'Experiment duration (sec)', 10)

  # Define the application to be installed on this type of node,
  # bind the application properties to the prototype properties,
  # and finally, define what measurements should be collected
  # for each application.
  #
  p.addApplication("test:app:iperf"){|iperf|
    iperf.bindProperty('client', 'client')
    iperf.bindProperty('time')
    iperf.bindProperty('window')
    iperf.measure('Peer_Info', :samples => 1)
    iperf.measure('TCP_received', :samples =>1)
  }
}

