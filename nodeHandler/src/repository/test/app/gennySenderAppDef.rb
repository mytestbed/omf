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



a = AppDefinition.create("gennySender")

a.url = "http://apps.orbit-lab.org/gennySender"

a.name = "gennySender"

a.version(0, 0, 1)

a.shortDescription = "Programmable traffic generator"

a.description = <<TEXT

Genny Sender is a custom UDP traffic generator that is able to send

packets at a constant bit rate. It can be configured to use libmac

or plain sockets as its underlying transport mechanism. Users can

change packet rates and payload lengths during the course of the

experiment. Genny sender uses pipes to accept run-time arguments

from users.

TEXT



# addProperty(name, description, mnemonic, type, isDynamic = false, constraints = nil)

a.addProperty('interface_name', "Interface to send on", ?i, :string, false)

#a.addProperty(:pipe_name, "Pipe on which genny sender listens on", ?p, String, false)

a.addProperty('rate', "Packet rate", ?r, :integer, true)

a.addProperty('payload_length', "Payload length (bytes)", ?l, :integer, true)

a.addProperty('use_socket', "Socket or Libmac", ?s, :boolean, false)



a.addMeasurement("group3", nil, [

  ["offered_load", Float]

])



a.repository("http://repository.orbit-lab.org/common/gennySender")

a.repository("http://controlpxe.orbit-lab.org/repository/genny-0.3.tar")



a.path = "/opt/genny/bin/gennySender"





if $0 == __FILE__

  a.to_xml.write($stdout, 2)

  puts

end



