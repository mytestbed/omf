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
Experiment.name = "tutorial-1a"
Experiment.project = "orbit:tutorial"

#
# Define nodes used in experiment
#
#Define node 1,2 as sender with 1024 byte CBR traffic at 300 kbps using UDP

defGroup('sender', [1,2]) {|node|
  node.image = nil  # assume the right image to be on disk

  node.prototype("test:proto:sender", {
    'destinationHost' => '192.168.1.1',
    'packetSize' => 1024,   #Packet size
    'rate' => 300,          #Offered load = 300 kbps
    'protocol' => 'udp'     #Protocol = UDP
  })
  node.net.w0.mode = "master" #802.11 Master Mode
}

defGroup('receiver', [1,1]) {|node|
  node.image = nil  # assume the right image to be on disk
  node.prototype("test:proto:receiver" , {
    'protocol' => 'udp'   #Use UDP to receive
  })
  node.net.w0.mode = "managed"
}

allGroups.net.w0 { |w|
  w.type = 'b'              #Set all nodes to use 802.11b
  w.essid = "helloworld"    #essid = helloworld
  w.ip = "%192.168.%x.%y"   #IP address = 192.168.x.y
}

#
# Now, start the application
#
whenAllInstalled() {|node|
  wait 30


  #This will start the traffic source on node 1-2 and sink on node1-1
  #Throughput will be reported in the database

  allNodes.startApplications
  wait 40

  Experiment.done
}


