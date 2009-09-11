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

require 'set'
require 'omf-common/arrayMD'
require 'net/http'
require 'omf-common/mobject'
require 'omf-expctl/nodeHandler.rb'

#
# Get the status of nodes within a given topology
#
def getStatus(topo, domain)

  puts "-----------------------------------------------"
  if topo.include?(":")
    filename = topo.delete("[]")
    t = Topology["#{filename}"]
  else
    begin
      t = Topology.create("mytopo", eval(topo))
    rescue Exception => e
      filename = topo.delete("[]")
      t = Topology["#{filename}"]
    end
  end
  d = (domain == "default") ?  OConfig.domain : domain
  puts " Testbed : #{d}"
  url = "#{OConfig[:tb_config][:default][:cmc_url]}/allStatus?domain=#{d}"
  response = NodeHandler.service_call(url, "Can't get node status from CMC")
  doc = REXML::Document.new(response.body)
  doc.root.elements.each('//detail/*') { |e|
    attr = e.attributes
    x = attr['x'].to_i
    y = attr['y'].to_i
    state = attr['state']
    if t.nodesArr[x][y] == [x,y]
      puts " Node n_#{x}_#{y} - State: #{state}" 
    end
  }
  puts "-----------------------------------------------"
end

# Get the global status of all the ndoes within a given testbed
#
def countNodeStatus(domain)
  nON = 0
  nOFF = 0
  nKO = 0
  d = (domain == "default") ?  OConfig.GRID_NAME : domain
  url = "#{OConfig[:tb_config][:default][:cmc_url]}/allStatus?domain=#{d}"
  response = NodeHandler.service_call(url, "Can't get node status from CMC")
  doc = REXML::Document.new(response.body)
  doc.root.elements.each('//detail/*') { |e|
    attr = e.attributes
    state = attr['state']
    nON = (state.match(/^POWERON/)) ? nON + 1 : nON
    nOFF = (state.match(/^POWEROFF/)) ? nOFF + 1 : nOFF
    nKO = (state.match(/^NODE/)) ? nKO + 1 : nKO
  }
  puts "-----------------------------------------------"
  puts "Testbed : #{d}"
  puts "Number of nodes in 'Power ON' state      : #{nON}"
  puts "Number of nodes in 'Power OFF' state     : #{nOFF}"
  puts "Number of nodes in 'Not Available' state : #{nKO}"
  puts "-----------------------------------------------"
end

# Main Execution loop of this software tool
#
begin
  topocmd = ARGV[0] # topo or command
  domain = ARGV[1] 
  NodeHandler.instance.loadControllerConfiguration()
  NodeHandler.instance.startLogger()
  OConfig.loadTestbedConfiguration()
  if (topocmd == "[-c]" || topocmd == "[--count]")
    countNodeStatus(domain)
  else
      Topology.useNodeClass = false
      TraceState.init()
      getStatus(topocmd, domain)
  end
end
