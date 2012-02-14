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

# Create an application representation from scratch

#

require "appDefinition.rb"



a = AppDefinition.create("gennyReceiver")

a.url = "http://apps.orbit-lab.org/gennyReceiver"

a.name = "gennyReceiver"

a.version(0, 0, 1)

a.shortDescription = "Traffic sink"

a.description = <<TEXT

Genny Revceiver is the receiving peer of the UDP traffic

generator that reports measurements such as RSSI, noise

and throughput. It can be configured to use

libmac (for RSSI measurement) or plain sockets

as its underlying transport mechanism.

TEXT



# addProperty(name, description, mnemonic, type, isDynamic = false, constraints = nil)

a.addProperty(:interface_name, "Interface to send on", ?i, :string, false)

a.addProperty(:use_socket, "Socket or Libmac", ?s, :boolean, false)





a.addMeasurement(:group1, nil, [

  [:rssi, AppMeasurement::FLOAT],

  [:noise, AppMeasurement::FLOAT]

])

a.addMeasurement(:group2, nil, [

  [:throughput, AppMeasurement::FLOAT]

])



a.repository("http://repository.orbit-lab.org/common/gennyReceiver")



if $0 == __FILE__

  a.to_xml.write($stdout, 2)

  puts

end



