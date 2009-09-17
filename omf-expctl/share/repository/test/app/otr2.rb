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

require 'omf-expctl/application/appDefinition'

# This is an OMF Definition for the existing application called 'otr2'
# This definition will allow OMF entities to use and instrument this application
#
defApplication('test:app:otr2', 'otr2') { |a|

  a.path = "/usr/bin/otr2"
  a.version(1, 1, 2)
  a.shortDescription = "Programmable traffic sink"
  a.description = <<TEXT
otr is a configurable traffic sink. It contains port to receive
packet streams via various transport options, such as TCP and UDP.
This version 2 is compatible with OMLv2.
TEXT

  # Define the properties that can be configured for this application
  # 
  # syntax: defProperty(name, description, mnemonic = nil, options = nil)
  #
  a.defProperty('udp:local_host', 'IP address of this Destination node', nil, {:type => :string, :dynamic => false})
  a.defProperty('udp:local_port', 'Receiving Port of this Destination node', nil, {:type => :integer, :dynamic => false})

  # Define the Measurement Points and associated metrics that are available for this application
  #
  a.defMeasurement('udp_in') { |m|
    m.defMetric('ts',:float)
    m.defMetric('flow_id',:long)
    m.defMetric('seq_no',:long)
    m.defMetric('pkt_length',:long)
    m.defMetric('dst_host',:string)
    m.defMetric('dst_port',:long)
  }
}
