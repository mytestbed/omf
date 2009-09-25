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
# Tutorial:  Hello World with Dynamic Experiment Properties 
#   
defProperty('sender', 1, "ID of sender node")
defProperty('smode', 'master', "Wifi mode for the sender (master/managed/adhoc)")
defProperty('pktsize', 256, "Packet size (byte) from the sender node")
defProperty('bitrate', 4096, "Bitrate (bit/s) from the sender node")
defProperty('receiver', 2, "ID of receiver node")
defProperty('rmode', 'managed', "Wifi mode for the receiver (master/managed/adhoc)")
defProperty('time', 20, "Time in second for the experiment is to run")

defGroup('source', [1,prop.sender]) {|node|
  node.prototype("test:proto:udp_sender", {
		'destinationHost' => "192.168.0.#{prop.receiver}",
		'localHost' => "192.168.0."+prop.sender,
                'packetSize' => prop.pktsize,
                'rate' => prop.bitrate
  })
  node.net.w0.mode = property.smode
}

defGroup('sink', [1,prop.receiver]) {|node|
  node.prototype("test:proto:udp_receiver" , {
		'localHost' => "192.168.0."+prop.receiver
  })
  node.net.w0.mode = prop.rmode
}

allGroups.net.w0 { |w|
	w.type = 'g'
	w.channel = "6"
	w.essid = "helloworld"
	w.ip = "%192.168.0.%y" 
}

whenAllInstalled() {|node|
  wait prop.time / 2
  allGroups.startApplications
  wait 2 + prop.time
  property.pktsize = 512
  property.bitrate = 8192
  wait prop.time
  allGroups.stopApplications
  wait prop.time * 2
  Experiment.done
}
