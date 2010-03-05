#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
# Copyright (c) 2004-2009 - WINLAB, Rutgers University, USA
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
# This service provides information on the 
# available nodes in the testbed and basic
# functionality to switch them on and off.
#

require 'omf-common/websupp'
require 'omf-aggmgr/ogs/legacyGridService'
require 'omf-aggmgr/ogs_cmc/cmcTestbed'
require 'omf-aggmgr/ogs_cmc/cmcNode'


class CmcService < LegacyGridService
  
  name 'cmc' # used to register/mount the service, the service's url will be based on it
  info 'Information on available testbed resources and simple control functionality'
  @@config = nil
  
  @@nodes = {}
  
  s_info 'Switch on a node at a specific coordinate'
  s_param :x, 'xcoord', 'x coordinates of location'
  s_param :y, 'ycoord', 'y coordinates of location'
  s_param :domain, '[domain]', 'domain for request.'
  s_auth :authorizeIP
  service 'on' do |req, res|
    x, y = getCoords(req)
    tb = getTestbedConfig(req, @@config)
    subDomain = req.query['subdomain']
    peerIp = req.query['ip']
    p "subDomain #{subDomain}"
    p "peerIp #{peerIp}"
    p "X= #{x}, Y= #{y}"
    p req.query
    self.responseOK(res)    
  end

  s_info 'Switch on a set of nodes'
  s_param :ns, 'nodeSet', 'set definition of nodes included.'
  s_param :domain, '[domain]', 'domain for request.'
  service 'nodeSetOn' do |req, res|
     ns = getNodeSetParam(req, 'ns')
     tb = getTestbedConfig(req, @@config) 
    self.responseOK(res)   
  end
  
  s_info 'Switch on all of the nodes'
  service 'allOn' do |req, res|
    self.responseOK(res)   
  end

  s_info 'Switch off a node HARD (immediately) at a specific coordinate'
  s_param :x, 'xcoord', 'x coordinates of location'
  s_param :y, 'ycoord', 'y coordinates of location'
  service 'offHard' do |req, res|
    self.responseOK(res)    
  end

  s_info 'Switch off a node SOFT (execute halt) at a specific coordinate'
  s_param :x, 'xcoord', 'x coordinates of location'
  s_param :y, 'ycoord', 'y coordinates of location'
  service 'offSoft' do |req, res|
    self.responseOK(res)    
  end
  
  s_info 'Switch off ALL nodes HARD (immediately)'
  service 'allOffHard' do |req, res|
    self.responseOK(res)    
  end

  s_info 'Switch off ALL nodes SOFT (execute halt)'
  service 'allOffSoft' do |req, res|
    self.responseOK(res)    
  end

  s_info 'Reset a node at a specific coordinate'
  s_param :x, 'xcoord', 'x coordinates of location'
  s_param :y, 'ycoord', 'y coordinates of location'
  service 'reset' do |req, res|
    self.responseOK(res)    
  end

  s_info 'Returns a list of all nodes in the testbed'
  service 'getAllNodes' do |req, res|
    tb = getTestbedConfig(req)
    
    nodes = eval(tb['listAll'])
    res.body = nodes.inspect
    res['Content-Type'] = "text"
  end
  
  s_info 'Returns the status of all nodes in the testbed'
  s_param :domain, '[domain]', 'domain for request.'
  service 'allStatus' do |req, res|
    tb = getTestbedConfig(req, @@config)
    root = REXML::Element.new('TESTBED_STATUS')
    detail = root.add_element('detail')
    
    nodes = eval(tb['listStatus'])
    nodes.each { |n|
      x = n[0]; y = n[1]
      attr = {'name' => "n_#{x}_#{y}", 'x' => x.to_s, 'y' => y.to_s, 'state' => 'POWERON' }
      detail.add_element('node', attr)
    }
    setResponse(res, root)
  end
  
    # Configure the service through a hash of options
  #
  def self.configure(config)
    @@config = config
  end
  
  def self.authorizeIP(req, res)
   domain = getParam(req, 'domain')
    peerDomain= Websupp.getPeerSubDomain(req)
    address = req.peeraddr[2]
    peerIp = Websupp.getAddress(address.rstrip)
  
   # We have to make sure that either the domain of the peer address
   # maches the requested testbed or that the address  
   # belongs to the set/range of addresses authorized to access nodes
   puts "Checking authorization for domain #{domain}' req=#{peerDomain}, peerIP=#{peerIp}"
   # We need to do parial match on subdomain and handle default as well ...
   isAuth = (domain == peerDomain)
   isAuth
 end
  
end

# We now register the service from the main code of 'ogs.rb'
#register(CmcService)
