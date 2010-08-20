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
# = statnode.rb
#
# == Description
#
# This file provides a sotfware tool to query the status of one or many node(s)
# It uses the existing Experiment Controller classes of OMF
#

require 'set'
require 'omf-common/arrayMD'
require 'net/http'
require 'omf-common/mobject'
require 'omf-expctl/nodeHandler.rb'

#
# Get the status of nodes within a given topology
# Results will be displayed directly on STDOUT
#
# - topo = the Topology to query for
# - domain =  the domain to query for
#
def getStatus(topo, domain)
  # TODO: use the topology here instead of showing the status for all
  puts "-----------------------------------------------"
  puts " Testbed : #{domain}"
  url = "#{OConfig[:ec_config][:cmc][:url]}/allStatus?domain=#{domain}"
  response = NodeHandler.service_call(url, "Can't get node status from CMC")
  doc = REXML::Document.new(response.body)
  doc.root.elements.each('//detail/*') { |e|
    attr = e.attributes
    puts " Node #{attr['name']}   \t State: #{attr['state']}" 
  }
  puts "-----------------------------------------------"
end

#
# Get the global status of all the ndoes within a given testbed
# Results will be displayed directly on STDOUT
# 
# - domain = the domain to query for
#
def countNodeStatus(domain)
  nON = 0
  nOFF = 0
  nKO = 0
  d = (domain == "default") ?  OConfig.domain : domain
  url = "#{OConfig[:ec_config][:cmc][:url]}/allStatus?domain=#{d}"
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

#
# Main Execution loop of this software tool
#
begin
  topocmd = ARGV[0] # topo or command
  NodeHandler.instance.loadControllerConfiguration()
  NodeHandler.instance.startLogger()
  OConfig.loadTestbedConfiguration()
  d = OConfig.domain ? OConfig.domain : "default"
  if (topocmd == "-s" || topocmd == "--summary")
    domain = ARGV[2] ? ARGV[2] : d
    countNodeStatus(domain)
  else
    Topology.useNodeClass = false
    TraceState.init()
    domain = ARGV[1] ? ARGV[1] : d
    getStatus(topocmd, domain)
  end
end
