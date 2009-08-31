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
require 'omf-expctl/application/appDefinition'

defApplication('test:app:otg2', 'otg2') {|a|
  a.version(1, 1, 2)
  a.shortDescription = "Programmable traffic generator v2"
  a.description = <<TEXT
OTG is a configurable traffic generator. It contains generators
producing various forms of packet streams and port for sending
these packets via various transports, such as TCP and UDP.
This version 2 is compatible with OMLv2
TEXT

  # defProperty(name, description, mnemonic, type, isDynamic = false, constraints = nil)
  #a.defProperty('oml-server', 'Contact details for the oml collection server')
  #a.defProperty('oml-id', 'ID for this oml client')
  #a.defProperty('oml-exp-id', 'ID for this experiment')
#
#
  a.defProperty('udp:broadcast', 'Broadcast', nil, {:type => :integer, :dynamic => false})
  a.defProperty('udp:dst_host', 'IP address of the Destination', nil, {:type => :string, :dynamic => false})
  a.defProperty('udp:dst_port', 'Destination Port to send to', nil, {:type => :integer, :dynamic => false})
  a.defProperty('udp:local_host', 'IP address of this Source node', nil, {:type => :string, :dynamic => false})
  a.defProperty('udp:local_port', 'Local Port of this source node', nil, {:type => :integer, :dynamic => false})
  a.defProperty("cbr:size", "Size of packet [bytes]", nil, {:dynamic => true, :type => :integer})
  a.defProperty("cbr:rate", "Data rate of the flow [bps]", nil, {:dynamic => true, :type => :integer})

  a.path = "/usr/bin/otg2"
}
