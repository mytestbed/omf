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
#

# Create an application representation from scratch

#

require "appDefinition.rb"





a = AppDefinition.create("nodeAgent")

a.url = "http://apps.orbit-lab.org/nodeAgent"

a.name = "NodeAgent"

a.version(0, 0, 1)

a.shortDescription = "Node Agent"

a.description = "\

    A node agent is active on every experiment node and communicates through \

    semantic multicast with all other agents in the system. It can control all the resources \

    on a node and can react to commands from the management agent to control \

    the life cycle of experiments on the respective node."



# addProperty(name, description, mnemonic, type, isDynamic = false, constraints = nil)

a.addProperty("channel_id", "Channel to send on", "c", "int", true)

a.addProperty("payload_length", "Length of payload of packet", "l", "int", true)





a.addMeasurement("group1", nil, [

  ["rssi", AppMeasurement::FLOAT],

  ["noise", AppMeasurement::FLOAT]

])

a.addMeasurement("group2", nil, [

  ["throughput", AppMeasurement::FLOAT]

])

a.addMeasurement("group3", nil, [

  ["offered_load", AppMeasurement::FLOAT]

])



a.to_xml.write($stdout, 2)

puts









