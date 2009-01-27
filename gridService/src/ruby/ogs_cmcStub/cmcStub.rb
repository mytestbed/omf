#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2008 - WINLAB, Rutgers University, USA
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
# = cmcStub.rb
#
# == Description
#
# This file defines CmcStubService class.
#

require 'net/telnet'
require 'ogs/gridService'

#
# This class defines the CMC (Chassis Manager Controller) Stub Service.
#
# A CMC Service normally provides information on the available nodes in a given
# testbed and basic functionality to switch them on and off.
# However, this particular CMC service is just a 'stub' that does not implement
# most CMC features, but instead answer 'OK' to most of the received requests. 
# It is temporarily needed to allow the NodeHandler to run on the NICTA platform
# where the experimental nodes have currently no CM functionalities.
#
# For more details on how features of this Service are implemented below, please
# refer to the description of the AbstractService class
#
class CmcStubService < GridService

  # name used to register/mount the service, the service's url will be based on it
  name 'cmc' 
  info 'Information on available testbed resources and simple control functionality'
  @@config = nil

  #
  # Implement 'on' service using the 'service' method of AbstractService
  # In this Stub CMC, this will always return HTTP OK
  #
  s_info 'Switch on a node at a specific coordinate'
  s_param :x, 'xcoord', 'x coordinates of location'
  s_param :y, 'ycoord', 'y coordinates of location'
  service 'on' do |req, res|
    self.responseOK(res)
  end
  
  #
  # Implement 'nodeSetOn' service using the 'service' method of AbstractService
  # In this Stub CMC, this will always return HTTP OK
  #
  s_info 'Switch on a set of nodes'
  s_param :nodes, 'setDecl', 'set of nodes to switch on'
  service 'nodeSetOn' do |req, res|
    self.responseOK(res)
  end
  
  #
  # Implement 'reset' service using the 'service' method of AbstractService
  # In this Stub CMC, this will always return HTTP OK
  #
  s_info 'Reset a node at a specific coordinate'
  s_param :x, 'xcoord', 'x coordinates of location'
  s_param :y, 'ycoord', 'y coordinates of location'
  service 'reset' do |req, res|
    self.responseOK(res)
  end

  #
  # Implement 'offHard' service using the 'service' method of AbstractService
  # In this Stub CMC, this will always return HTTP OK
  #
  s_info 'Switch off a node HARD (immediately) at a specific coordinate'
  s_param :x, 'xcoord', 'x coordinates of location'
  s_param :y, 'ycoord', 'y coordinates of location'
  service 'offHard' do |req, res|
    self.responseOK(res)
  end
  
  #
  # Implement 'offSoft' service using the 'service' method of AbstractService
  #
  # NOTE: 
  # At NICTA, we do not have the CM card operational on our nodes yet...
  # We use the NA's 'REBOOT' command to implement a 'offSoft'
  #
  s_info 'Switch off a node SOFT (execute halt) at a specific coordinate'
  s_param :x, 'xcoord', 'x coordinates of location'
  s_param :y, 'ycoord', 'y coordinates of location'
  service 'offSoft' do |req, res|
    x = getParam(req, 'x')
    y = getParam(req, 'y')
    MObject.debug("CMCSTUB - Sending REBOOT cmd to NA at [#{x},#{y}]")
    begin
      # Connect to the NA running on the Node
      theNodeAgent = Net::Telnet::new('Host' => "10.0.0.#{y}",
                                      'Port' => 9026,
                                      'Timeout' => 0.01,
                                      'Telnetmode' => false)
      # Send a REBOOT message to this NA
      theNodeAgent.write("0 10.0.0.#{y} REBOOT")
      #theNodeAgent.close()
    rescue Exception => ex
      MObject.debug("CMCSTUB - Failed to send REBOOT to [#{x},#{y}] - Exception: #{ex}")
    end
    self.responseOK(res)
  end

  #
  # Implement 'allOffHard' service using the 'service' method of AbstractService
  # In this Stub CMC, this will always return HTTP OK
  #
  s_info 'Switch off ALL nodes HARD (immediately)'
  service 'allOffHard' do |req, res|
    self.responseOK(res)
  end
  
  #
  # Implement 'allOffSoft' service using the 'service' method of AbstractService
  #
  # NOTE: 
  # At NICTA, we do not have the CM card operational on our nodes yet...
  # We use the NA's 'REBOOT' command to implement a 'allOffSoft'
  #
  s_info 'Switch off ALL nodes SOFT (execute halt)'
  service 'allOffSoft' do |req, res|
    tb = getTestbedConfig(req, @@config)
    nodes = eval(tb['listAll'])
    nodes.each { |n|
      x = n[0]; y = n[1]
      #x = 1; y = 2
      MObject.debug("CMCSTUB - Sending REBOOT cmd to NA at [#{x},#{y}]")
      begin
        # Connect to the NA running on the Node
        theNodeAgent = Net::Telnet::new('Host' => "10.0.0.#{y}",
                                      'Port' => 9026,
                                      'Timeout' => 0.01,
                                      'Telnetmode' => false)
        # Send a REBOOT message to this NA
        theNodeAgent.write("0 10.0.0.#{y} REBOOT")
        #theNodeAgent.close()
      rescue Exception => ex
        MObject.debug("CMCSTUB - Failed to send REBOOT to [#{x},#{y}]")
      end
    }
    self.responseOK(res)
  end

  #
  # Implement 'getAllNodes' service using the 'service' method of AbstractService
  #
  # NOTE: 
  # At NICTA, we do not have the CM card operational on our nodes yet...
  # We use the information in the CMC Stub config file to implement a 'getAllNodes'
  #
  # TODO: if still not CM card operational after a while, then this should 
  # really use information from the Inventory instead
  #
  s_info 'Returns a list of all nodes in the testbed'
  service 'getAllNodes' do |req, res|
    tb = getTestbedConfig(req, @@config)

    nodes = eval(tb['listAll'])
    res.body = nodes.inspect
    res['Content-Type'] = "text"
  end

  #
  # Implement 'allStatus' service using the 'service' method of AbstractService
  #
  # NOTE: 
  # At NICTA, we do not have the CM card operational on our nodes yet...
  # We use the information in the CMC Stub config file to implement a 'allStatus'
  #
  # TODO: if still not CM card operational after a while, then this should 
  # really use information from the Inventory instead
  #
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
  
  #
  # Configure the service through a hash of options
  #
  # - config = the Hash holding the config parameters for this service
  #
  def self.configure(config)
    @@config = config
  end
end
