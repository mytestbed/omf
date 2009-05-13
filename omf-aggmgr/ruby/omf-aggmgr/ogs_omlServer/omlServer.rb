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
# = omlserver.rb
#
# == Description
#
# This file defines the OmlServerService class.
#
# NOTE: OmlServerService is deprecated, please use Oml2ServerService instead
# 
#

require 'ogs/gridService'
require 'ogs_omlServer/omlServerd'

#
# NOTE: OmlServerService is deprecated, please use Oml2ServerService instead
#       Since this class is deprecated, we did not include RDoc comments in its
#       code below. 
# 
class OmlServerService < GridService

  name 'oml'
  info 'Interface to OML collection server'
  @@config = nil

  s_info 'Start a collection server. The config information is expected to be in the body.'
  service 'start' do |req, res|
    content = req.body
    if (content == nil)
      raise HTTPStatus::BadRequest, "Missing configure information in body"
    end
    io = StringIO.new(content)
    doc = REXML::Document.new(io, {:compress_whitespace => :all})
    root = doc.root
    if root.name != 'experiment'
      raise "Expected 'experiment' as root of XML document, but found '#{root.name}'"
    end
    req.query['config_root'] = root
    req.query['id'] ||= root.attributes['id'] || DateTime.now.strftime("%F-%T").split(':').join('-')
    req.query['domain'] = root.attributes['domain']
    d = OmlServerDaemon.start(req)
    # Built the XML response - same output as gridservices1
    root = REXML::Element.new("collection_server")
    root.add_attribute('id', d.daemon_id)
    attr = Hash.new
    attr['port'] = d.port
    attr['addr'] = d.addr
    attr['iface'] = d.iface
    root.add_element("multicast-channel", attr)
    setResponse(res, root)

  end

  s_info 'Stop a collection server \'id\'.'
  s_param :id, 'daemon_id', 'identifier of oml server'
  service 'stop' do |req, res|
    OmlServerDaemon.stop(req)
    responseOK(res)
  end


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

  s_info 'Report status of collection servers. \
  If \'id\' is provided only return status for that.'
  s_param :id, '[daemon_id]', 'identifier of oml server'
  service 'status' do |req, res|
    id = getParamDef(req, 'id', nil)
    list = id.nil? ? OmlServerDaemon.all : [OmlServerDaemon[id]]
    root = REXML::Element.new('oml_status')
    list.each { |d|
      d.serverDescription(root)
    } if list != nil
    setResponse(res, root)
  end

  # Configure the service through a hash of options
  #
  def self.configure(config)
    @@config = config
    OmlServerDaemon.configure(config)
  end

end

