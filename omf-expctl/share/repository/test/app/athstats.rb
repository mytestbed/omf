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

a = AppDefinition.create('test:app:athstats')
a.name = "athstats"
a.version(0, 0, 1)
a.shortDescription = "Application to gather madwifi driver statistics"
a.description = <<TEXT
This C application gathers driver statistics and reports them.
TEXT

# addProperty(name, description, mnemonic, type, isDynamic = false, constraints = nil)
a.addProperty('interface', 'Use ath0/ath1, ath0 by default', nil, :string, false)
a.addProperty('interval', 'Number of msec between calls to query driver', nil, :string, false)

a.addMeasurement("queryport", nil, [
    ['succ_tx_attempts', 'int'],
    ['fail_xretries', 'int'],
    ['fail_fifoerr', 'int'],
    ['fail_filtered', 'int'],
    ['short_retries', 'int'],
    ['long_retries', 'int'],
    ['total_frames_rcvd', 'int'],
    ['crc_errors', 'int'],
    ['fifo_errors', 'int'],
    ['phy_errors', 'int']
 ])
a.path = "/usr/bin/athstats-oml"

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

