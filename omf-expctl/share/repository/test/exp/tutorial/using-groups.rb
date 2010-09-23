#
# Copyright (c) 2006-2010 National ICT Australia (NICTA), Australia
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
# Tutorial experiment
#
defProperty('res1', 'omf.nicta.node1', "ID of sender node")
defProperty('res2', 'omf.nicta.node2', "ID of receiver node")
defProperty('duration', 60, "Duration of the experiment")

defGroup('Sender', property.res1) do |node|
  node.addApplication("test:app:otg2") do |app|
    app.setProperty('udp:local_host', '%net.w0.ip%')
    app.setProperty('udp:dst_host', '192.168.255.255')
    app.setProperty('udp:broadcast', 1)
    app.setProperty('udp:dst_port', 3000)
    app.measure('udp_out', :samples => 1)
  end
end

defGroup('Receiver', property.res2) do |node|
  node.addApplication("test:app:otr2") do |app|
    app.setProperty('udp:local_host', '192.168.255.255')
    app.setProperty('udp:local_port', 3000)
    app.measure('udp_in', :samples => 1)
  end
end

allGroups.net.w0 do |interface|
  interface.mode = "adhoc"
  interface.type = 'g'
  interface.channel = "6"
  interface.essid = "helloworld"
  interface.ip = "192.168.0.%index%"
end

onEvent(:ALL_UP_AND_INSTALLED) do |event|
  wait 10
  group("Receiver").startApplications
  wait 5
  group("Sender").startApplications
  wait property.duration
  group("Sender").stopApplications
  wait 5
  group("Receiver").stopApplications
  Experiment.done
end
