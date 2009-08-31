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

defApplication('test:app:otl2', 'otl2') {|a|
  a.version(1, 1, 2)
  a.shortDescription = "Programmable traffic passive listener"
  a.description = <<TEXT
OTL is a passive traffic listener. It uses libpcap to access 
packets (and their info) going through a given interface. It is 
equivalent to a 'tcpdump' but with support for OMLv2.
TEXT

  # defProperty(name, description, mnemonic, type, isDynamic = false, constraints = nil)
  a.defProperty('oml-server', 'Contact details for the oml collection server')
  a.defProperty('oml-id', 'ID for this oml client')
  a.defProperty('oml-exp-id', 'ID for this experiment')
  a.defProperty('pcap', 'File with the definition of filters to use')
  a.defProperty('pcap-if', 'When using the default filter, listen on this given interface')
  a.defProperty('pcap-ip-src', 'When using the default filter, select pkt with this Src IP')
  #a.defProperty('pcap-ip-dst', 'When using the default filter, select pkt with this Dst IP')

  a.path = "sudo /usr/bin/app_pcap_oml2"
  #a.path = "sudo /bin/otl2"
}
