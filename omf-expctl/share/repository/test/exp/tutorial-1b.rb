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
Experiment.name = "tutorial-1b"
Experiment.project = "orbit:tutorial"

#
# Define various elements used in the experiment
#

defProperty('rate', 300, 'Bits per second sent from sender')
defProperty('packetSize', 1024, 'Size of packets sent from sender')

#
# Define nodes used in experiment
#
defGroup('sender', [1,2]) {|node|
  node.image = nil  # assume the right image to be on disk

  node.prototype("test:proto:sender", {
    'destinationHost' => '192.168.1.4',
    'packetSize' => prop.packetSize,
    'rate' => prop.rate,
    'protocol' => 'udp'
  })
  node.net.w0.mode = "managed"
}

defGroup('receiver', [1,4]) {|node|
  node.image = nil  # assume the right image to be on disk
  node.prototype("test:proto:receiver" , {
    'hostname' => '192.168.1.4',
    'protocol' => 'udp'
  })
  node.net.w0.mode = "master"
}

allGroups.net.w0 { |w|
  w.type = 'b'
  w.essid = "helloworld"
  w.ip = "%192.168.%x.%y"
}

#
# Now, start the application
#
whenAllInstalled() {|node|
  wait 30

  prop.packetSize = 256
  prop.rate = 200
  allNodes.startApplications

  wait 30
  prop.packetSize = 1024
  prop.rate = 350

  wait 30
  allNodes.stopApplications
  Experiment.done
}


