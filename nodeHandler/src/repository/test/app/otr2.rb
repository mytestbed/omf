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
require 'handler/appDefinition'

defApplication('test:app:otr2', 'otr2') { |a|

  a.version(1, 1, 2)
  a.shortDescription = "Programmable traffic sink"
  a.description = <<TEXT
otr is a configurable traffic sink. It contains port to receive
packet streams via various transport options, such as TCP and UDP.
This version 2 is compatible with OMLv2.
TEXT

  #defProperty(name, description, mnemonic = nil, options = nil)
  a.defProperty('oml-server', 'Contact details for the oml collection server')
  a.defProperty('oml-id', 'ID for this oml client')
  a.defProperty('oml-exp-id', 'ID for this experiment')
  a.defProperty('udp:local_host', 'IP address of this Destination node')
  a.defProperty('udp:local_port', 'Receiving Port of this Destination node')
  #a.defProperty('sink', 'Processing to do with received packets [udpi|udpmi]', nil, {:type => :string, :dynamic => false})
  #a.defProperty('udpmi:local_host', 'IP address of the local host ', nil, {:type => :string, :dynamic => false})
  #a.defProperty("debug-level", "debug level [integer]")

  a.path = "/bin/otr2"
}
