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
require 'omf-expctl/appDefinition'

defApplication('test:app:otg2_mp', 'otg2_mp') {|a|
  a.version(1, 1, 2)
  a.shortDescription = "Programmable traffic generator v2"
  a.description = <<TEXT
OTG is a configurable traffic generator. It contains generators
producing various forms of packet streams and port for sending
these packets via various transports, such as TCP and UDP.
Version 2 introduces multipath routing, ie. OTG sends pkt via
multiple paths to the destination.
TEXT

  # defProperty(name, description, mnemonic, type, isDynamic = false, constraints = nil)
  a.defProperty('protocol', 'Protocol to use [udpm|udp|tcp]')
  a.defProperty('generator', 'Generator to use [cbr|expoo]')

  a.defProperty('udpm:local_host', 'IP address of the local host [string]')
  a.defProperty('udpm:dst_host', 'IP address of the destination host [string]')
  a.defProperty('udpm:disjoint', 'Flag to use (or not) disjoint paths [0 or 1]')

  a.defProperty("debug-level", "debug level [integer]")

  a.path = "/bin/otg2_mp"
}


if $0 == __FILE__
  require 'omf-expctl/appDefinition'
  require 'stringio'
  require 'rexml/document'
  include REXML

  sio = StringIO.new()
  a = AppDefinition['test:app:otg2_mp']
  a.to_xml.write(sio, 2)
  sio.rewind
  puts sio.read

  sio.rewind
  doc = Document.new(sio)
  t = AppDefinition.from_xml(doc.root)

  puts
  puts "-------------------------"
  puts
  t.to_xml.write($stdout, 2)

 end

