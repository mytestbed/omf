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
# Define a prototype
#

defPrototype("test:proto:probelink") { |p|
  
  p.name = "ProbeLink"
  p.description = "Get some characteristics of the wireless interface using the wlanconfig list command"

  # Define some properties for this prototype
  #
  p.defProperty('omlServer', 'Contact details for the oml collection server', "tcp:#{OmlApp.getServerAddr}:#{OmlApp.getServerPort}")
  p.defProperty('id', 'ID for this oml client', "/tmp/#{Experiment.ID}")
  p.defProperty('expId', 'ID for this experiment', "/tmp/#{Experiment.ID}")

  # Set the OML application definition to use
  #
  p.addApplication(:wlanconfig_oml2, "test:app:wlanconfig_oml2") { |wlan|
    wlan.bindProperty('oml-server', 'omlServer')
    wlan.bindProperty('oml-id', 'id')
    wlan.bindProperty('oml-exp-id', 'expId')
  }

}
