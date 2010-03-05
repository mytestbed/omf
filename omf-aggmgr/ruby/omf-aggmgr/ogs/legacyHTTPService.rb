#
# Copyright (c) 2006-2010 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2010 - WINLAB, Rutgers University, USA
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
# = legacyHTTPService.rb
#
# == Description
#
# This file defines the LegacyHTTPService class.
#

require 'omf-aggmgr/ogs/abstractService'

class LegacyHTTPService < AbstractService


  #
  # Associate this Service to the GridService Server, i.e. mount the handlers
  # for this service as sub-nodes of the GS Server URI.
  #
  # - server = instance of the Web Server that runs in the GS Server
  # - prefix = optional, prefix where this Service should be 'mounted'
  #            (default = '/serviceName')
  #
  def self.mount(server, prefix = "/#{self.serviceName}")
    services = @@services[self] || {}
    services.each { |name, params|
      mountPoint = "#{prefix}/#{name}"
      MObject.debug(serviceName, "Mounting #{mountPoint}")
      if (auth = params[:auth])
        m = self.method(auth)
        #puts "Auth #{m}:#{m.class}"
        server.mount_proc(mountPoint) {|req,res|
          if m.call(req,res)
            params[:proc].call(req,res)
          else
            raise WEBrick::HTTPStatus::Unauthorized.new()
          end
        }
      else
        server.mount_proc(mountPoint, params[:proc])
      end
    }

    server.mount_proc(prefix) {|req, res|
      res['ContentType'] = "text/xml"
      ss = StringIO.new()
      ss.write("<?xml version='1.0'?>\n")
      doc = REXML::Document.new
      root = doc.add(REXML::Element.new("services"))
      el = to_xml(root)
      el.attributes['prefix'] = prefix
      formatter = REXML::Formatters::Default.new
      formatter.write(doc,ss)
      res.body = ss.string
    }
  end
end
