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
require 'handler/application/appDefinition'

defApplication('test:app:wlanconfig_oml2', 'wlanconfig_oml2') { |a|

  a.version(1, 1, 1)
  a.shortDescription = "Get information about the wireless network"
  a.description = <<TEXT
This application get information about the neighbours of the node using the wlanconfig command
TEXT

  a.defProperty('oml-server', 'Contact details for the oml collection server')
  a.defProperty('oml-id', 'ID for this oml client')
  a.defProperty('oml-exp-id', 'ID for this experiment')

  # Where to find the application 'wlanconfig_oml2' which calls wlanconfig 
  # and parses its outputs
  a.path = "/usr/bin/wlanconfig_oml2"
}
