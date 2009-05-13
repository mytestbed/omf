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
# = oml2server.rb
#
# == Description
#
# This file defines the Oml2ServerService class.
#
#

require 'ogs/gridService'
require 'ogs_oml2Server/oml2Serverd'

#
# This class defines a Service to control (start/stop) an OML2 Collection server
#
# For more details on how features of this Service are implemented below, please
# refer to the description of the AbstractService class
#
class Oml2ServerService < GridService

  # used to register/mount the service, the service's url will be based on it
  name 'oml2'
  info 'Interface to OMLv2 collection server'
  @@config = nil

  #
  # Implement 'start' service using the 'service' method of AbstractService
  #
  s_info 'Start a collection server. This new version will get all the DB-related config from the client(s).'
  s_param :id, '[id]', 'the id to give to this OML server.'
  s_param :domain, '[domain]', 'domain for request.'
  service 'start' do |req, res|
    req.query['domain'] ||= getParam(req, 'domain') || "default"
    req.query['id'] ||= getParam(req, 'id') || "#{req.query['domain']}-#{DateTime.now.strftime("%F-%T").split(':').join('-')}"
    d = Oml2ServerDaemon.start(req)
    # Built the XML response - same output as gridservices1
    root = REXML::Element.new("oml2_collection_server")
    root.add_attribute('id', d.daemon_id)
    attr = Hash.new
    attr['port'] = d.port
    attr['addr'] = d.addr
    root.add_element("channel", attr)
    setResponse(res, root)
  end

  #
  # Implement 'stop' service using the 'service' method of AbstractService
  #
  s_info 'Stop a collection server \'id\'.'
  s_param :id, 'daemon_id', 'identifier of oml server'
  service 'stop' do |req, res|
    Oml2ServerDaemon.stop(req)
    responseOK(res)
  end

  #
  # Implement 'log' service using the 'service' method of AbstractService
  #
  s_info 'Return the log of collection server \'id\'.'
  s_param :id, 'daemon_id', 'identifier of oml server'
  service 'log' do |req, res|
    id = getParam(req, 'id')
    d = OmlServerDaemon[id]
    if (d == nil)
      raise HTTPStatus::NotFound, "Unknown service '#{id}'"
    end
    handler = HTTPServlet::DefaultFileHandler.new(@@server, d.logFile)
    handler.do_GET(req, res)
  end
  
  #
  # Implement 'status' service using the 'service' method of AbstractService
  #
  s_info 'Report status of collection servers. \
  If \'id\' is provided only return status for that.'
  s_param :id, '[daemon_id]', 'identifier of oml server'
  service 'status' do |req, res|
    id = getParamDef(req, 'id', nil)
    list = id.nil? ? Oml2ServerDaemon.all : [Oml2ServerDaemon[id]]
    root = REXML::Element.new('oml2_status')
    list.each { |d|
      d.serverDescription(root)
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
    Oml2ServerDaemon.configure(config)
  end

end

