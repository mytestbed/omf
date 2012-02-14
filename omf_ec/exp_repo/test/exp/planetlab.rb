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
Experiment.name = "planetlab"
Experiment.project = "orbit-planetlab:tutorial"

#Backup PlanetLab nodes
#ssh -v -l orbit_pkamat -i ~/.ssh/identity alice.cs.princeton.edu
#ssh -v -l orbit_pkamat -i ~/.ssh/identity pli2-pa-1.hpl.hp.com
#ssh -v -l orbit_pkamat -i ~/.ssh/identity planetlab2.rutgers.edu
#ssh -v -l orbit_pkamat -i ~/.ssh/identity pli2-pa-1.hpl.hp.com
#ssh -v -l orbit_pkamat -i ~/.ssh/identity pli2-pa-2.hpl.hp.com
#ssh -v -l orbit_pkamat -i ~/.ssh/identity pli2-pa-3.hpl.hp.com

#Launch http server on the Planetlab node
#runCmd("ssh -v -l orbit_pkamat -i ~/.ssh/identity alice.cs.princeton.edu \"sudo /etc/init.d/httpd start\"")
runCmd(" #{LAUNCH_ON_PLANETLAB} \"sudo /etc/init.d/httpd start\"")

#
# Define nodes used in experiment
#
#  node 1,2 is the media proxy fetching the stream from PlanetLab
#  and relaying to node8-7

defGroup('vlcrelay', [1,2]) {|node|
  node.image = nil  # assume the right image to be on disk

    node.prototype("test:proto:vlcrelay", {
    })
    node.net.w0.mode = "master" #802.11 Master Mode
  }

defGroup('vlcdest', [8,7]) {|node|
  node.image = nil  # assume the right image to be on disk

    node.prototype("test:proto:vlcdest", {
    })
    node.net.w0.mode = "managed" #802.11 Master Mode
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

 #Start the relaying application on the wireless side
 allNodes.startApplications

 #Run the experiment for 60 seconds
 wait 60

 #Stop the Planetlab media service
 runCmd("ssh -v -l orbit_pkamat -i ~/.ssh/identity alice.cs.princeton.edu \"sudo /etc/init.d/httpd stop\"")

 Experiment.done
}
