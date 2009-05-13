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
require 'net/http'
require 'uri'

Experiment.name = "tutorial-1"
Experiment.project = "orbit:tutorial"
Experiment.documentRoot = '../repository/public_html/exp/conf_room_demo'

#
# Define various elements used in the experiment
#

defProperty('rate', 300, 'Bits per second sent from sender')
defProperty('packetSize', 256, 'Size of packets sent from sender')
defProperty('startExp', 0, 'Start experiment flag')
defProperty('numSendGroups', 7, 'Number of Sender Groups')

#defNodes('sender1', [[1,2],[1,4],[1,6],[1,8]])
defGroup('sender1', [[1,2],[1,4],[1,8]])
defGroup('sender2', [[2,1],[2,3],[2,5]])
defGroup('sender3', [[3,2],[3,4],[3,6],[3,8]])
defGroup('sender4', [[4,1],[4,3],[4,5],[4,7]])
defGroup('sender5', [[5,2],[5,8],[6,3],[6,5]])
defGroup('sender6', [[6,7],[7,2],[7,4],[7,6]])
defGroup('sender7', [[8,1],[8,5],[8,7]])

defGroup('receiver', [5,4]) {|node|
  node.image = nil  # assume the right image to be on disk
  node.prototype("test:proto:receiver" , {
    'hostname' => '192.168.5.4',
    'protocol' => 'udp'
  })
  node.net.w0.mode = "master"
  node.net.w0.essid = "helloworld"
  node.net.w0.type = 'a'
  node.net.w0.ip = "%192.168.%x.%y"
}

wait 5

defGroup('sender', ['sender1', 'sender2', 'sender3', 'sender4', 'sender5', 'sender6', 'sender7']) { |node|
  node.image = nil  # assume the right image to be on disk
  node.prototype("test:proto:sender", {
    'destinationHost' => '192.168.5.4',
    'packetSize' => Experiment.property("packetSize"),
    'rate' => Experiment.property("rate"),
    'protocol' => 'udp'
  })
  node.net.w0.mode = "managed"
  node.net.w0.essid = "helloworld"
  node.net.w0.type = 'a'
  node.net.w0.ip = "%192.168.%x.%y"
}

#
# Now, start the application
#
whenAllInstalled() {|node|
  Experiment.props.packetSize = 1024
  Experiment.props.rate = 1500
#  Experiment.props.rate = 10000
  Experiment.props.startExp = 0
  Experiment.props.numSendGroups = 5

  wait 10
  nodes('receiver').startApplications

  # Slowly adding traffic
  (1..7).each {|i|
    group = "sender#{i}"
    info "Starting applications on #{group}"
    nodes(group).startApplications
    wait 10
  }
  wait 50

  # Slowly removing traffic
  (1..7).each {|i|
    group = "sender#{i}"
    info "Stopping applications on #{group}"
    nodes(group).stopApplications
    wait 5
  }

  Experiment.done
}


