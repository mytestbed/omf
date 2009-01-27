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

defApplication('test:app:otg', 'otg') {|a|
  a.version(1, 1, 2)
  a.shortDescription = "Programmable traffic generator"
  a.description = <<TEXT
OTG is a configurable traffic generator. It contains generators
producing various forms of packet streams and port for sending
these packets via various transports, such as TCP and UDP.
TEXT

  # defProperty(name, description, mnemonic, type, isDynamic = false, constraints = nil)
  a.defProperty('protocol', 'Protocol to use [udp|tcp]')
  a.defProperty('generator', 'Generator to use [cbr|expoo]')
  #UDP/TCP
  a.defProperty("port",  "Local port to bind to [int]", nil, {:type => :integer})
  a.defProperty("dsthostname", "Name of destination host [string]")
  a.defProperty("dstport", "Destination port to send to")
  a.defProperty("broadcast", "broadcast on/off")

  # RAW
  a.defProperty("txdev","the device to tranmsit packets")
  a.defProperty("dstmacaddr", "MAC address of the destination")

  # CBR Generator
  a.defProperty("size", "Size of packet [bytes]", nil,
                  {:dynamic => true, :type => :integer})
  a.defProperty("interval", "Internval between consecutive packets [msec]", nil,
                  {:dynamic => true, :type => :integer})
  a.defProperty("rate", "Data rate of the flow [kbps]", nil,
                  {:dynamic => true, :type => :integer})

  # Exponential On/Off traffic generator
  a.defProperty("ontime", "average burst length in milliseconds", nil,
                  {:dynamic => true, :type => :integer})
  a.defProperty("offtime", "average idle time in milliseconds", nil,
                  {:dynamic => true, :type => :integer})

  #pause/resume
  a.defProperty("pause", "pause the sender", nil,
                  {:dynamic => true, :type => nil})
  a.defProperty("resume", "resume the sender", nil,
                  {:dynamic => true, :type => nil})

  a.defMeasurement("senderport") { |m|
    m.defMetric('pkt_seqno', 'long', 'Sequence number of packet')
    m.defMetric('pkt_size', 'long', 'Size of packet in ??')
    m.defMetric('gen_timestamp', Float, 'Time when packet was generated')
    m.defMetric('tx_timestamp', 'long', 'Time when packet was sent')
  }

  #a.aptName = 'orbit-otg'
  a.path = "/usr/bin/otg"
}


if $0 == __FILE__
  require 'handler/appDefinition'
  require 'stringio'
  require 'rexml/document'
  include REXML

  sio = StringIO.new()
  a = AppDefinition['test:app:otg']
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

