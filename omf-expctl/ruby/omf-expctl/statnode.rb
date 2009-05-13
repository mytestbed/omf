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
require 'omf-expctl/exceptions.rb'
require 'omf-expctl/property'
require 'omf-expctl/traceState'
require 'omf-expctl/experiment'
require 'omf-expctl/oconfig'
require 'omf-expctl/topology'
require 'omf-expctl/handlerCommands'

# Stub Class for the NodeHandler
# The current OMF classe/module are so tighly coupled that nothing can be
# done without a NodeHandler object.
# TODO: "clean" the entire OMF design to remove this non-relevant dependencies
# 
class NodeHandler
  DOCUMENT = REXML::Document.new
  ROOT_EL = DOCUMENT.add(REXML::Element.new("context"))
  LOG_EL = ROOT_EL.add_element("log")
  EXPERIMENT_EL = ROOT_EL.add_element("experiment")
  def NodeHandler.JUST_PRINT()
    return false
  end
  def NodeHandler.SLAVE_MODE()
    return false
  end
  def NodeHandler.getTS()
    return DateTime.now.strftime("%T")
  end
  def NodeHandler.service_call(url, error_msg)
    begin
      response = Net::HTTP.get_response(URI.parse(url))
      if (! response.kind_of? Net::HTTPSuccess)
        raise ServiceException.new(response, error_msg)
      end
      response
    rescue Exception => ex
      puts "service_call - Exception: #{ex} (#{ex.class})"
    end
  end
end

# Load the NodeHandler config file
# So this software tool will use the same config as NodeHandler
# (e.g. address for CMC, maximum X and Y for topologies, etc..) 
# 
def loadGridConfigFile()
  cfgFile = "nodehandler.yaml"
  path = ["/etc/omf-expctl/#{cfgFile}"]
  path.each {|f|
    if File.exists?(f)
      OConfig.init(f)
      return
    end
  }
  raise "Can't find #{cfgFile} in #{path.join(':')}"
end

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
  d = (domain == "default") ?  OConfig.GRID_NAME : domain
  puts " Testbed : #{d}"
  url = "#{OConfig.CMC_URL}/allStatus?domain=#{d}"
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
  url = "#{OConfig.CMC_URL}/allStatus?domain=#{d}"
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
  loadGridConfigFile()
  if (topocmd == "[-c]" || topocmd == "[--count]")
    countNodeStatus(domain)
  else
      Topology.useNodeClass = false
      TraceState.init()
      getStatus(topocmd, domain)
  end
end
