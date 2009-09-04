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
# Define a prototype containing a single
# traffic generator (otg).
#


defPrototype("test:proto:udp_sender") { |p|
  p.name = "UDP_Sender"
  p.description = "A node which transmit a stream of packets over multiple paths"

  p.defProperty('destinationHost', 'Host to send packets to')
  p.defProperty('destinationPort', 'Host to send packets to',3000)
  p.defProperty('localHost', 'Host that generate the packets', 'localhost')
  p.defProperty('localPort', 'Host that generate the packets',3000)
  p.defProperty('packetSize', 'Size of packets [bytes]', 512)
  p.defProperty('rate', 'Number of bits per second [bps]', 4096)
  p.defProperty('broadcast', 'Allow broadcast', 0)

  # Define applications to be installed on this type of node,
  # bind the application properties to the prototype properties,
  # and finally, define what measurements should be collected
  # for each application.
  #
  p.addApplication("test:app:otg2") {|otg|
    otg.bindProperty('udp:broadcast', 'broadcast')	
    otg.bindProperty('udp:dst_host', 'destinationHost')
    otg.bindProperty('udp:dst_port', 'destinationPort')
    otg.bindProperty('udp:local_host', 'localHost')
    otg.bindProperty('udp:local_port', 'localPort')
    otg.bindProperty('cbr:size', 'packetSize')
    otg.bindProperty('cbr:rate', 'rate')

    #otg.measure(:mpoint => 'udp_out')
    
    #otg.measure(:mpoint => 'udp_out', :interval => 1)
    #otg.measure(:mpoint => 'udp_out', :samples => 10)
    
    #otg.measure(:mpoint => 'udp_out', :interval => 5) do |mp|
      #mp.metric('myMetrics', 'seq_no' )
      #mp.metric('myMetrics', 'dst_host' )
      #mp.metric('myMetrics', 'seq_no', 'pkt_length', 'dst_host' )
    #end


    otg.measure(:mpoint => 'udp_out', :interval => 5) do |mp|
      
      mp.filter(:name => 'myFilter1', :type => 'avg', 
                :options => {:input => 'pkt_length'})
      
      mp.filter(:name => 'myFilter2', :type => 'first', 
                :options => {:input => 'dst_host'})

      mp.filter(:name => 'myFilter2', :type => 'first', 
                :options => {:input => 'dst_host'})
      #mp.filter(:name => 'myFilter2', :type => 'histogram', 
      #                       :options => {:inputs => ['pkt_length', 'dst_host'], 
      #                                    :category => 5})
    end

  }
}
