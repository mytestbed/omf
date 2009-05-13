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

a = AppDefinition.create('test:app:itgs')
a.name = "itgs"
a.version(0, 0, 1)
a.shortDescription = "D-ITG Sender"
a.description = <<TEXT
ITGSend is a traffic generator for TCP and UDP traffic. It contains generators
producing various forms of packet streams and port for sending
these packets via various transports, such as TCP and UDP.
TEXT

# addProperty(name, description, mnemonic, type, isDynamic = false, constraints = nil)
#Flow options
a.addProperty('m', 'MSR type: either onewaydelay or RTT', ?m, :string, false)
a.addProperty('a', 'Destination address', ?a, :string, false)
a.addProperty('r', 'Remote port', ?r, :integer, false)
a.addProperty('T', 'Protocol type TCP/UDP/UDP_Libmac', ?T, :integer, false)
a.addProperty('f', 'TTL',?f, :integer, false)
a.addProperty('d', 'Gen_Delay',?d, :integer, false)
a.addProperty('t', "Duration of traffic generation(millisecs)", ?t, :integer, false)

#Interdeparture time options
a.addProperty('C', 'Constant interdeparture time b/w packets (pkts_per_s)', ?C, :integer, false)
a.addProperty('E', '(Exponential) Average packets per sec', ?E, :integer, false)
a.addProperty('O', '(Poisson) Average pkts per sec', ?O, :integer, false)
#Note that Pareto, Cauchy, UNiform, Normal and Gamma distributions will be added

#Log file options
a.addProperty('l', 'Log file', ?l, :string, false)

#Packet size options
a.addProperty('c', 'Constant payload size', ?c, :integer, false)
a.addProperty('e', "Average pkt size (exponential)", ?e, :integer, false)
a.addProperty('o', "Poisson distributed avg. pkt size", ?o, :integer, false)
#Note that Pareto, Cauchy, UNiform, Normal and Gamma distributions will be added

# Applications (note that no other interdeparture or packet size can be chosen
# if an application is chosen
a.addProperty('App', 'VoIP traffic', ?Z, :integer, false)
a.addProperty('codec', 'VoIP codec: G.711.1, G.711.2, G.723.1, G.729.2, G.729.3', ?i, :string, false)
a.addProperty('voip_control', 'protocol_type RTP or CRTP',?h, :string, false)

a.addProperty('Telnet', 'Telnet traffic', nil, :integer, false)
a.addProperty('DNS', 'DNS traffic', nil, :integer, false)


a.addMeasurement("senderport", nil, [
    ['stream_no', 'int'],
    ['pkt_seqno', 'long'],
    ['pkt_size', 'long'],
    ['gen_timestamp', 'long'],
    ['tx_timestamp', 'long']
 ])

a.path = "/usr/local/bin/ITGSend"

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

