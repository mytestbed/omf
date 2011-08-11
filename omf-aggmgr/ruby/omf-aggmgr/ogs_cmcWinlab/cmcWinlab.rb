opyright (c) 2006-2011 National ICT Australia (NICTA), Australia
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

require 'omf-aggmgr/ogs/gridService'
require 'net/http'

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
class CmcWinlabService < GridService

  # name used to register/mount the service, the service's url will be based on it
  name 'cmcw'
  description 'Translator for WINLABs old CMC service to understand the new HRN format'
  @@config = nil

  #
  # Implement 'on' service using the 'service' method of AbstractService
  #
  # Note: Correct behaviour of 'on' is
  #       - if node is already ON do nothing
  #       - if node is OFF then turn it ON
  #
  s_description 'Switch ON a resource'
  s_param :hrn, 'hrn', 'hrn of the resource'
  s_param :domain, 'domain', 'domain for request.'  
  service 'on' do |hrn, domain|
      call_cmc("on",hrn,domain)
  end
 
  #
  # Implement 'reset' service using the 'service' method of AbstractService
  #
  # Note: Correct behaviour of 'reset' is
  #       - if node is already ON, then reset/reboot it
  #       - if node is OFF then turn it ON
  #
  s_description 'Reset a resource (hard)'
  s_param :hrn, 'hrn', 'hrn of the resource'
  s_param :domain, 'domain', 'domain for request.'
  service 'reset' do |hrn, domain|
    call_cmc("reset",hrn,domain)
  end
  
  #
  # Implement 'reboot' service using the 'service' method of AbstractService
  #
  # Soft reboot via telnet or SSH
  #
  s_description 'Reboot a resource (soft)'
  s_param :hrn, 'hrn', 'hrn of the resource'
  s_param :domain, 'domain', 'domain for request.'
  service 'reboot' do |hrn, domain|
    call_cmc("reset",hrn,domain)
  end

  #
  # Implement 'offHard' service using the 'service' method of AbstractService
  #
  s_description 'Switch off a node (hard)'
  s_param :hrn, 'hrn', 'hrn of the resource'
  s_param :domain, 'domain', 'domain for request.'
  service 'offHard' do |hrn, domain|
    call_cmc("offHard",hrn,domain)
  end
  
  #
  # Implement 'offSoft' service using the 'service' method of AbstractService
  #
  s_description 'Switch off a node (reboot, soft)'
  s_param :hrn, 'hrn', 'hrn of the resource'
  s_param :domain, 'domain', 'domain for request.'
  service 'offSoft' do |hrn, domain|
    call_cmc("offSoft",hrn,domain)
  end

  #
  # Configure the service through a hash of options
  #
  # - config = the Hash holding the config parameters for this service
  #
  def self.configure(config)
    @@config = config
  end
  
  def self.call_cmc(action, hrn, domain)
    MObject.debug("CDEBUG - '#{hrn}','#{domain}','#{action}'")
    coord = hrn.to_s().scan(/\d+/)
    # TODO move this to the config file
    old_cmc_url = 'http://cmc:5012/cmc'
    if coord.length < 2
      error "Invalid HRN: #{hrn}"
      raise Exception.new
    end
    
    url = "#{old_cmc_url}/#{action}?x=#{coord[0]}&y=#{coord[1]}&domain=#{domain}"
    MObject.debug("CDEBUG - '#{hrn}','#{domain}','#{action}','#{url}'") 
    
    response = Net::HTTP.get_response(URI.parse(url))
    if (! response.kind_of? Net::HTTPSuccess)
      error "CMC call unsuccessful - #{response.inspect}"
      raise Exception.new
    end
       
  end

end
