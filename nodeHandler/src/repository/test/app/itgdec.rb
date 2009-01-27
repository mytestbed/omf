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

a = AppDefinition.create('test:app:itgdec')
a.name = "itgdec"
a.version(0, 0, 1)
a.shortDescription = "D-ITG Decoder"
a.description = <<TEXT
This program decodes the output of the experiment
TEXT

# addProperty(name, description, mnemonic, type, isDynamic = false, constraints = nil)
a.addProperty('logfile', 'Log file', ?x , :string, false)
a.addProperty('d', 'Delay interval size (msec)', ?d, :integer, false)
a.addProperty('j', 'Jitter Interval size (msec)', ?j, :integer, false)
a.addProperty('b', 'Bitrate interval size (msec)', ?b, :integer, false)
a.addProperty('p', 'Packet loss interval size(msec)', ?p, :integer, false)

a.addMeasurement("decoderport", nil, [
    ['flow_no', 'int'],
    ['src_port', 'int'],
    ['dst_port', 'int'],
    ['throughput', Float],
    ['jitter', Float],
    ['delay',Float],
    ['pkt_loss', Float],
    ['rssi', Float],
    ['rate', Float]
 ])

a.path = "/usr/local/bin/ITGDec"

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

