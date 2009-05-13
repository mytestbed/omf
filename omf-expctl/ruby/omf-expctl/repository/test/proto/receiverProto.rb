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

# Define a prototype

#



require "prototype.rb"

require "filter.rb"

require "nodeSet.rb"



require "test/gennyReceiverAppDef"



p = Prototype.create("http://apps.orbit-lab.org/receiver")

p.name = "Receiver"

p.description = "Nodes which receive a stream of packets"

p.addParameter(:if, "name of interface to use", Node::W0_IF)

p.addParameter(:useSocket, "If true use socket, otherwise use libmac for transport", true)

p.addParameter(:sampleSize, "size of samples to average over (OML)", 100)



genny = p.addApplication(:gennyReceiver, "http://apps.orbit-lab.org/gennyReceiver#gennyReceiver")

genny.bindProperty(:interface_name, :if)

genny.bindProperty(:use_socket, :useSocket)



genny.addMeasurement(:group3,  Filter::SAMPLE,

  {Filter::SAMPLE_SIZE => :$sampleSize},

  [

    ["offered_load", Filter::MEAN]

  ]

)



genny.addMeasurement(:group1, Filter::SAMPLE,

  {Filter::SAMPLE_SIZE => :$sampleSize},

  [

    [:rssi, Filter::MEAN],

    [:noise, Filter::MEAN]

  ]

)

genny.addMeasurement(:group2,  Filter::SAMPLE,

  {Filter::SAMPLE_SIZE => 100},

  [

    [:throughput, Filter::MEAN]

  ]

)





if $0 == __FILE__

  p.to_xml.write($stdout, 2)

  puts

end



