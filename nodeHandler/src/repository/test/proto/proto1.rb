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

# Define a prototype

#



require "handler/prototype.rb"

require "handler/filter.rb"



require "handler/appDef1.rb"



p = Prototype.create("sender")

p.name = "Sender"

p.description = "Nodes which send a stream of packets"

p.addParameter(:payload_length, "payload length of outgoing packets", 1000)

p.addParameter(:channel, "Channel to send on", 1)



nodeAgent = p.addApplication("http://apps.orbit-lab.org/nodeAgent#nodeAgent")

nodeAgent.bindProperty(:payload_length)

nodeAgent.bindProperty(:channel_id, :channel)



nodeAgent.addMeasurement(:group1, Measurement::SAMPLE,

  {:trigger => 3},

  [

    [:rssi, Filter::MIN_MAX],

    [:noise, Filter::MEAN]

  ])



# Alternative syntax

m3 = nodeAgent.addMeasurement(:group2, Measurement::SAMPLE)

m3.setProperty(:trigger, 3, :sec)

m3.addMetric(:throughput).addFilter(Filter::MIN_MAX, {:foo => 3})





p.to_xml.write($stdout, 2)

puts

