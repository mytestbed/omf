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
#
# = frisbee.rb
#
# == Description
#
# This file defines the FrisbeeService class.
#

require 'omf-aggmgr/ogs/legacyGridService'
require 'omf-aggmgr/ogs_frisbee/frisbeed'

#
# This class defines a Service to control a Frisbee server. A Frisbee server
# is used to distribute disk image in an efficient manner among the nodes of a
# given testbed.
#
# For more details on how features of this Service are implemented below, please
# refer to the description of the AbstractService class
#
class FrisbeeService < LegacyGridService

  # used to register/mount the service, the service's url will be based on it
  name 'frisbee'
  description 'Service to control frisbee servers to stream specific images'
  @@config = nil

  #
  # Implement 'checkImage' service using the 'service' method of AbstractService
  #
  s_description 'Check if a given disk image really exist on the repository'
  s_param :img, '[imgName]', 'name of image to check.'
  service 'checkImage' do |req, res|
    config = getTestbedConfig(req, @@config)
    image = getParamDef(req, 'img', nil)
    imagePath = "#{config['imageDir']}/#{image}"
    res['Content-Type'] = "text"
    if ! File.readable?(imagePath)
      MObject.error("FrisbeeService - checkImage - '#{image}' DOES NOT EXIST !")
      res.body = "IMAGE NOT FOUND"
    else
      res.body = "OK"
    end
  end

  #
  # Implement 'getAddress' service using the 'service' method of AbstractService
  #
  s_description 'Get the port number of a frisbee server serving a specified image (start a new server if none exists)'
  s_param :img, '[imgName]', 'name of image to serve [defaultImage].'
  s_param :domain, '[domain]', 'domain for request.'
  service 'getAddress' do |req, res|
    d = FrisbeeDaemon.start(req)
    res['Content-Type'] = "text"
    res.body = d.getAddress()
  end

  #
  # Implement 'stop' service using the 'service' method of AbstractService
  #
  s_description 'Stop serving a specified image'
  s_param :img, '[imgName]', 'name of image to serve [defaultImage].'
  s_param :domain, '[domain]', 'domain for request.'
  service 'stop' do |req, res|
    d = FrisbeeDaemon.stop(req)
    res['Content-Type'] = "text"
    res.body = "OK"
  end

  #
  # Implement 'status' service using the 'service' method of AbstractService
  #
  s_description 'Returns the list of all served image'
  s_param :img, '[imgName]', 'If defined, only report about that image.'
  s_param :domain, '[domain]', 'domain for request.'
  service 'status' do |req, res|
    img = getParamDef(req, 'img', nil)
    domain = getParam(req, 'domain')
    name = FrisbeeDaemon.daemon_name(req)
    list = img == nil ? FrisbeeDaemon.all : [FrisbeeDaemon[name]]
    # Build the header of the XML response
    root = REXML::Element.new("frisbee_status")
    root.add_element("bandwidth")
    root.add_element("mc_address")
    bw = Float("#{FrisbeeDaemon.getBandwidth}") / 1000000.0
    root.elements["bandwidth"].text = bw
    root.elements["mc_address"].text = "#{FrisbeeDaemon.getMCAddress}"
    # Build the rest of the XML response
    list.each { |d|
      root = d.serverDescription(root)
    } if list != nil
    setResponse(res, root)
  end

  #
  # Configure the service through a hash of options
  #
  # - config = the Hash holding the config parameters for this service
  #
  def self.configure(config)
    @@config = config
    FrisbeeDaemon.configure(config)
  end

end



