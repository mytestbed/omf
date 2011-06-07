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

# This is an OMF Prototype definition
# This prototype contains a single UDP traffic sink, which uses the
# existing modified application otr2_mp.
# Note: the application 'otr2_mp' was contributed by a student and is not 
# officially supported by the OMF/OML team
#
defPrototype("test:proto:receiver2_mp") do |p|
  
  p.name = "Receiver2-Multipah"
  p.description = "Nodes which receive packets from multiple paths"
  # List properties of prototype
  p.defProperty('sink', 'Task to perform on received packets', 'udpmi')
  p.defProperty('localHost', 'Host that generate the packets')
  p.defProperty('debugLevel', 'Level of debug messages to output', 0)

  # Define applications to be installed on this type of node,
  # bind the application properties to the prototype properties.
  #
  p.addApplication("test:app:otr2_mp") do |otr|
    otr.bindProperty('sink')
    otr.bindProperty('udpmi:local_host', 'localHost')
    otr.bindProperty('debug-level', 'debugLevel')
  end
end
