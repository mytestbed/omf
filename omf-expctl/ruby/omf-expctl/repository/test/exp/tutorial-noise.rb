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

Experiment.name = "tutorial-1a"
Experiment.project = "orbit:tutorial"
Experiment.defProperty('noisePower', -44, 'Noise level injected')
#
# Define nodes used in experiment
#
defGroup('sender', [1,2]) {|node|
  node.image = nil  # assume the right image to be on disk

  node.prototype("test:proto:sender", {
    'destinationHost' => '192.168.1.1',
    'packetSize' => 1024,
    'rate' => 300,
    'protocol' => 'udp'
  })
  node.net.w0.mode = "master"
}

defGroup('receiver', [1,1]) {|node|
  node.image = nil  # assume the right image to be on disk
  node.prototype("test:proto:receiver" , {
    'hostname' => '192.168.1.1',
    'protocol' => 'udp'
  })
  node.net.w0.mode = "managed"
}


allGroups.net.w0 { |w|
  w.type = 'b'
  w.essid = "helloworld"
  w.ip = "%192.168.%x.%y"
}

antenna(4,4).signal {|s|
  s.bandwidth = 20
  s.channel = 36
  s.power = prop.noisePower
}

#
# Now, start the application
#
whenAllInstalled() {|node|


  #Then start receiver and sender
  NodeSet['receiver'].startApplications
  wait 30
  NodeSet['sender'].startApplications

  antenna(4,4).signal.on

  # Step noise power from -44 to 0dbm in steps of 4db
  -44.step(0, 4) { |p|

    prop.noisePower = p
     wait 5
   }

  wait 10

  Experiment.done
}


