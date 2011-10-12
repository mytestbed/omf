#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
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
# = cmcStub.rb
#
# == Description
#
# This file defines CmcStubService class.
#

require 'net/telnet'
require 'omf-aggmgr/ogs/gridService'

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
  description 'Information on available testbed resources and simple control functionality'
  @@config = nil

  #
  # Implement 'on' service using the 'service' method of AbstractService
  # In this Stub CMC, this will always return true (OK)
  #
  # Note: Correct behaviour of 'on' is
  #       - if node is already ON do nothing
  #       - if node is OFF then turn it ON
  #
  s_description 'Switch ON a resource'
  s_param :hrn, 'hrn', 'hrn of the resource'
  s_param :domain, 'domain', 'domain for request.'  
  service 'on' do |hrn|
    true
  end

  #
  # Implement 'offHard' service using the 'service' method of AbstractService
  # In this Stub CM, this will try to send a REBOOT command to the RC on the 
  # resource using Telnet or SSH.
  # In this Stub CMC, this will always return true (OK)
  #
  s_description 'Switch off a node HARD (immediately) at a specific coordinate'
  s_param :hrn, 'hrn', 'hrn of the resource'
  s_param :domain, 'domain', 'domain for request.'  
  service 'offHard' do |hrn, domain|
    reboot(hrn, domain)
    true
  end

  #
  # Implement 'offSoft' service using the 'service' method of AbstractService
  # In this Stub CM, this will try to send a REBOOT command to the RC on the 
  # resource using Telnet or SSH.
  # In this Stub CMC, this will always return true (OK)
  #
  s_description 'Switch off a node SOFT (execute halt) at a specific coordinate'
  s_param :hrn, 'hrn', 'hrn of the resource'
  s_param :domain, 'domain', 'domain for request.'
  service 'offSoft' do |hrn, domain|
    reboot(hrn, domain)
    true
  end

  #
  # Implement 'reboot' service using the 'service' method of AbstractService
  # In this Stub CM, this will try to send a REBOOT command to the RC on the 
  # resource using Telnet or SSH.
  # Regardless of the result, this will always return true (OK)
  #
  s_description 'Reboot a resource (soft)'
  s_param :hrn, 'hrn', 'hrn of the resource'
  s_param :domain, 'domain', 'domain for request.'
  service 'reboot' do |hrn, domain|
    reboot(hrn, domain)
    true
  end



  #
  # Implement 'reset' service using the 'service' method of AbstractService
  # In this Stub CM, this will try to send a REBOOT command to the RC on the 
  # resource using Telnet or SSH.
  # Regardless of the result, this will always return true (OK)
  #
  s_description 'Reset a resource'
  s_param :hrn, 'hrn', 'hrn of the resource'
  s_param :domain, 'domain', 'domain for request.'
  service 'reset' do |hrn, domain|
    reboot(hrn, domain)
    true
  end

  #
  # Implement 'status' service using the 'service' method of AbstractService
  # In this Stub CMC, this will always return true (POWERON)
  #
  # Return the power state of a given node
  #
  s_description 'Return the power state of a given node'
  s_param :hrn, 'hrn', 'hrn of the resource'
  s_param :domain, 'domain', 'domain for request.'
  service 'status' do |hrn, domain|
    root = REXML::Element.new('NODE_STATUS')
    detail = root.add_element('detail')
    attr = {'hrn' => hrn, 'state' => "POWERON" }
    detail.add_element('node', attr)
    root
  end

  #
  # Configure the service through a hash of options
  #
  # - config = the Hash holding the config parameters for this service
  #
  def self.configure(config)
    @@config = config
  end

  def self.reboot(hrn, domain)
    MObject.debug("Sending REBOOT cmd to '#{hrn}'")
    ip = getControlIP(hrn, domain)
    begin
      cmd = `nmap #{ip} -p22-23`
      if cmd.include? "22/tcp open"
        ssh = `ssh -o CheckHostIP=no -o StrictHostKeyChecking=no #{ip} reboot`
      elsif cmd.include? "23/tcp open"
        tn = Net::Telnet::new('Host' => ip)
        tn.puts "root"
        tn.puts "reboot"
      end
    rescue Exception => ex
      MObject.debug("CMCSTUB - Failed to send REBOOT to '#{hrn}' at #{ip} - "+
                    "Exception: #{ex}")
    end
  end

end
