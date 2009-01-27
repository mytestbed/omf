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
require 'handler/appDefinition'

a = AppDefinition.create('test:app:iperfs')
a.name = "iperfs"
a.version(0, 0, 1)
a.shortDescription = "Iperf traffic generator"
a.description = <<TEXT
Iperf is a traffic generator for TCP and UDP traffic. It contains generators
producing various forms of packet streams and port for sending
these packets via various transports, such as TCP and UDP.
TEXT

# addProperty(name, description, mnemonic, type, isDynamic = false, constraints = nil)
a.addProperty('udp', 'Use UDP, otherwise TCP by default', nil, :string, false)
a.addProperty('client', 'Run as client', nil, :string, false)
a.addProperty('port', 'Sender port number', nil, :integer, false)
a.addProperty('window', 'TCP Send Window Size', nil, :integer, false)
a.addProperty('len', "Payload length (bytes)", nil, :integer, false)
a.addProperty('bandwidth', "Offered load for UDP", nil, :integer, false)
a.addProperty('time', "Duration of traffic generation(secs)", nil, :integer, false)
a.addProperty('parallel', "Number of parallel flows", nil, :integer, false)

a.addMeasurement("senderport", nil, [
    ['stream_no', 'int'],
    ['pkt_seqno', 'long'],
    ['pkt_size', 'long'],
    ['gen_timestamp', 'long'],
    ['tx_timestamp', 'long']
 ])

a.path = "/usr/bin/iperf"

if $0 == __FILE__
  require 'stringio'
  require 'rexml/document'
  include REXML

  sio = StringIO.new()
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

