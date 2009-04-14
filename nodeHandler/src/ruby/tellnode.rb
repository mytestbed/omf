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
require 'set'
require 'util/arrayMD'
require 'net/http'
require 'util/mobject'
require 'handler/exceptions.rb'
require 'handler/property'
require 'handler/traceState'
require 'handler/experiment'
require 'handler/oconfig'
require 'handler/topology'
require 'handler/handlerCommands'

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
      #puts "service_call - Exception: #{ex} (#{ex.class})"
    end
  end
  def self.debug?
  end
end

# Load the NodeHandler config file
# So this software tool will use the same config as NodeHandler
# (e.g. address for CMC, maximum X and Y for topologies, etc..) 
# 
def loadGridConfigFile()
  cfgFile = "nodehandler.yaml"
  path = ["/etc/nodehandler4-4.4.0/#{cfgFile}", "/etc/nodehandler4/#{cfgFile}"]
  path.each {|f|
    if File.exists?(f)
      OConfig.init(f)
      return
    end
  }
  raise "Can't find #{cfgFile} in #{path.join(':')}"
end

def getTopo(topo)
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
  return t
end

# Get the status of nodes within a given topology
#
def tellNode(cmd, topo, domain)
  puts "---------------------------------------------------"
  d = (domain == nil) ?  OConfig.GRID_NAME : domain
  command = nil
  if (cmd == "on" || cmd == "-on" || cmd == "--turn-on")
    command = "on"
  elsif (cmd == "offs" || cmd == "-offs" || cmd == "--turn-off-soft")
    command = "offSoft"
  elsif (cmd == "offh" || cmd == "-offh" || cmd == "--turn-off-hard")
    command = "offHard"
  end
  if command == nil
    puts "ERROR - Unknown command : '#{cmd}'" 
    puts "Use 'help' to see usage information" 
    puts ""
    exit 1
  end
  puts " Testbed : #{d} - Command: #{command}"
  topo.eachNode { |n|
    url = "#{OConfig.CMC_URL}/#{command}?x=#{n[0]}&y=#{n[1]}&domain=#{d}"
    response = NodeHandler.service_call(url, "Can't send command to CMC")
    if (response.kind_of? Net::HTTPOK)
      puts " Node n_#{n[0]}_#{n[1]} - Ok"
    else
      puts " Node n_#{n[0]}_#{n[1]} - Error (node state: 'Not Available')"
    end
  }
  puts "---------------------------------------------------"
end

# Main Execution loop of this software tool
#
begin
  puts " "  
  cmd = ARGV[0] 
  topo = ARGV[1] 
  domain = ARGV[2] 
  loadGridConfigFile()
  Topology.useNodeClass = false
  TraceState.init()
  puts "tellnode - TDEBUG - topo: '#{topo}'"
  theTopo = getTopo(topo)
  tellNode(cmd, theTopo, domain)
end
