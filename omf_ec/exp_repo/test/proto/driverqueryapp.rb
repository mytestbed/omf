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
# Define a prototype
#

p = Prototype.create("test:proto:driverqueryapp")
p.name = "Wireless Driver Stats"
p.description = "Statistics obtained by querying the driver periodically"
p.defProperty('interface', 'interface to gather stats from')
p.defProperty('interval', 'How often to query the driver')

athstats = p.addApplication(:athstats, "test:app:athstats")
athstats.bindProperty('interface')
athstats.bindProperty('interval')

athstats.addMeasurement('queryport',  Filter::SAMPLE,
  {Filter::SAMPLE_SIZE => 1},
  [
    ['succ_tx_attempts'],
    ['fail_xretries'],
    ['fail_fifoerr'],
    ['fail_filtered'],
    ['short_retries'],
    ['long_retries'],
    ['total_frames_rcvd'],
    ['crc_errors'],
    ['fifo_errors'],
    ['phy_errors']
  ]
)

if $0 == __FILE__
  p.to_xml.write($stdout, 2)
  puts
end

