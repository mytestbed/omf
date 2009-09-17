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

# This is an OMF Prototype definition
# This prototype contains a single UDP traffic receiver, which uses the
# existing application otr2.
# It allows OMF entities to use and instrument this traffic receiver
#
defPrototype("test:proto:udp_receiver") { |p|
  p.name = "UDP_Receiver"
  p.description = "Nodes which receive UDP packets"

  # Define the properties (and their default values) that can be configured 
  # for this prototype
  #
  p.defProperty('localHost', 'Host that generate the packets', 'localhost')
  p.defProperty('localPort', 'Host that generate the packets', 3000)

  # Define the application to be installed on this type of node,
  # bind the application properties to the prototype properties,
  # and finally, define what measurements should be collected
  # for each application.
  #
  p.addApplication("test:app:otr2") { |otr|

    otr.bindProperty('udp:local_host', 'localHost')
    otr.bindProperty('udp:local_port', 'localPort')
    
    otr.measure('udp_in', :interval => 1)
    # Other valid measurement definitions...
    #
    #otg.measure('udp_in')
    #otg.measure('udp_in', :interval => 5)
    #otg.measure('udp_in', :sample => 5)
    #otg.measure('udp_in', :interval => 5) do |mp|
      #mp.metric('myMetrics', 'seq_no' )
      #mp.metric('myMetrics', 'dst_host' )
      #mp.metric('myMetrics', 'seq_no', 'pkt_length', 'dst_host' )
      #mp.filter('myFilter1', 'avg', :input => 'pkt_length')
      #mp.filter('myFilter2', 'first', :input => 'dst_host')
    #end
  }
}
