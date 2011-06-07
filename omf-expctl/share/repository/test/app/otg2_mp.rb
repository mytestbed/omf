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

# This is an OMF Definition for the existing application called 'otg2_mp'
# This definition will allow OMF entities to use and instrument this application
# Note: the application 'otg2_mp' was contributed by a student and is not 
# officially supported by the OMF/OML team
# 
defApplication('test:app:otg2', 'otg2') do |a|

  a.path = "/usr/bin/otg2_mp"
  a.version(1, 1, 2)
  a.shortDescription = "Programmable *multipath* traffic generator v2"
  a.description = <<TEXT
OTG is a configurable traffic generator. It contains generators
producing various forms of packet streams and port for sending
these packets via various transports, such as TCP and UDP.
This modified version introduces multipath routing, ie. OTG sends pkt via
multiple paths to the destination.
TEXT

  # Define the properties that can be configured for this application
  # 
  # syntax: defProperty(name, description, mnemonic = nil, options = nil)
  #
  a.defProperty('protocol', 'Protocol to use [udpm|udp|tcp]')
  a.defProperty('generator', 'Generator to use [cbr|expoo]')
  a.defProperty('udpm:local_host', 'IP address of the local host [string]')
  a.defProperty('udpm:dst_host', 'IP address of the destination host [string]')
  a.defProperty('udpm:disjoint', 'Flag to use (or not) disjoint paths [0 or 1]')
  a.defProperty("debug-level", "debug level [integer]")

  # Note: here we should have some Measurement Point definition...
end
