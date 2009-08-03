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
# Define a prototype containing a single
# traffic listener (otl).
#


defPrototype("test:proto:listener2") { |p|
  p.name = "Listener2"
  p.description = "A node which listen for packets through a given interface"
  # List properties of prototype
  p.defProperty('omlServer', 'Contact details for the oml collection server', "tcp:#{OmlApp.getServerAddr}:#{OmlApp.getServerPort}")
  p.defProperty('id', 'ID for this oml client', "#{Experiment.ID}")
  p.defProperty('expId', 'ID for this experiment', "#{Experiment.ID}")
  p.defProperty('filter', 'The file with the filter definitions', "default")
  p.defProperty('interface', 'When using the default filter, listen on this given interface')
  p.defProperty('sourceIP', 'When using the default filter, select pkt with this Src IP')
  #p.defProperty('destinationIP', 'When using the default filter, select pkt with this Dst IP')

  # Define applications to be installed on this type of node,
  # bind the application properties to the prototype properties,
  # and finally, define what measurements should be collected
  # for each application.
  #
  p.addApplication(:otl2, "test:app:otl2") {|otl|
    otl.bindProperty('oml-server', 'omlServer')
    otl.bindProperty('oml-id', 'id')
    otl.bindProperty('oml-exp-id', 'expId')
    otl.bindProperty('pcap', 'filter')
    otl.bindProperty('pcap-if', 'interface')
    otl.bindProperty('pcap-ip-src', 'sourceIP')
    #otl.bindProperty('pcap-ip-dst', 'destinationIP')
  }
}

if $0 == __FILE__
  p.to_xml.write($stdout, 2)
  puts
end
