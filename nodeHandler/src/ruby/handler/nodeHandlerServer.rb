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
# = nodeHandlerServer.rb
#
# == Description
#
# This file implements a small web server to observe the status of a nodeHandler
#

require 'webrick'
require 'webrick/httputils'
require 'stringio'
require 'util/mobject'

include WEBrick

#
# This module implements a light WebServer based on the WEBrick library.
# This webserver is used to observe the status of the Node Handler
#
module NodeHandlerServer

  @@server = nil

  #
  # Start a new web-server (in a new Thread) to report on the NH's status
  #
  # - port = optional, port to listen to (default=2000)
  # - args = optional, arguments for the server
  #
  def NodeHandlerServer.start(port = 2000, args = {})

    args[:Port] = port

    mimeTable = HTTPUtils::DefaultMimeTypes
    mimeTable.update({ "xsl" => "text/xml" })
    args[:MimeTypes] = mimeTable

    MObject.debug(:web, "Configuring internal web server: #{args.inspect}")
    @@server = HTTPServer.new(args)
    @@server.mount("/xml", XMLServlet)
    @@server.mount("/xpath", XPathServlet)
    @@server.mount("/set", SetExpPropertyServlet)

    OConfig.REPOSITORY_DEFAULT.each { |dir|
      public = "#{dir}/public_html"
      if File.directory?(public)
        MObject.debug(:web, "Mounting /resource to #{public}")
        @@server.mount("/resource", HTTPServlet::FileHandler, public, true)
        break
      end
    }
    Thread.new {
      begin
        MObject.debug(:web, "Starting web server")
        @@server.start
      rescue => ex
        MObject.error(:web, "Internal web server died. #{ex}")
      end
    }
  end

  #
  # Return the URL of this NH's webserver
  #
  # [Return] a String wih the URL
  #
  def NodeHandlerServer.url()
    addr = @@server.listeners[0].addr
    # Check if NH is running in 'Slave' Mode
    if NodeHandler.SLAVE_MODE()
       # Yes - then other entities should access NH's web server on localhost
      return "http://127.0.0.1:#{addr[1]}"
    else
      return "http://#{OConfig.NODE_HANDLER_HOST}:#{addr[1]}"
    end
  end

  #
  # Map a given URL path to the corresponding servlet handler
  #
  # - path = the URL path to map
  # - servlet = the servlet which will handle services at that path
  #
  def NodeHandlerServer.map(path, servlet)
    @@server.mount(path, servlet)
  end

  #
  # Map a given URL path to a corresponding file 
  #
  # - path = the URL path to map
  # - *options = options to pass to the FileHandler HTTP Servlet
  #
  def NodeHandlerServer.mapFile(path, *options)
    @@server.mount(path, HTTPServlet::FileHandler, *options)
  end

  #
  # Map a given URL path to a given code-block
  #
  # - path = the URL path to map
  # - &block = the code-block which will be executed for that path
  #
  def NodeHandlerServer.mapProc(path, &block)
    @@server.mount_proc(path, &block)
  end

  #
  # Set the HTTP Document Root
  #
  # - path = the path to be used as the HTTP Document Root
  #
  def NodeHandlerServer.documentRoot(path)
    @@server.mount("/", HTTPServlet::FileHandler, path)
  end

  #
  # Stop the NH's webserver
  #
  def NodeHandlerServer.stop()
    @@server.shutdown if @@server != nil
    @@server = nil
  end

  #
  # This class defines a XML Servlet (subclass of HTTPServlet::AbstractServlet)
  #
  class XMLServlet < HTTPServlet::AbstractServlet
    #
    # Process an incoming HTTP 'GET' request
    #
    # - req = the full HTTP 'GET' request
    # - res = the HTTP reply to send back
    #
    def do_GET(req, res)
      res['Content-Type'] = "text/xml"
      ss = StringIO.new()
      ss.write("<?xml version='1.0'?>\n")

      xslt = req.query['xslt']
      if (xslt != nil)
        ss.write("<?xml-stylesheet href='#{xslt}' type='text/xsl'?>")
      end

      xpath = req.query['xpath']
      if (xpath == nil)
        #NodeHandler::DOCUMENT.write(ss, 2, true, true)
        NodeHandler::DOCUMENT.write(ss, 2)
      else
        ss.write("<match>\n")
        match = REXML::XPath.match(NodeHandler::DOCUMENT, xpath)
        match.each { |frag|
          frag.write(ss, 2)
        }
        ss.write("</match>\n")
      end
      res.body = ss.string
    end
  end

  #
  # This class defines a XPath Servlet (subclass of HTTPServlet::AbstractServlet)
  #
  class XPathServlet < HTTPServlet::AbstractServlet
    #
    # Process an incoming HTTP 'GET' request
    #
    # - req = the full HTTP 'GET' request
    # - res = the HTTP reply to send back
    #
    def do_GET(req, res)
      q = req.query['q']
      filter = req.query['f']

      res['ContentType'] = "text/xml"
      ss = StringIO.new()
      ss.write("<?xml version='1.0'?>\n")
      ss.write("<match>\n")
      match = REXML::XPath.match(NodeHandler::DOCUMENT, q)
      #match.write(ss, 2, true, true)
      if (filter == nil)
        match.each { |frag|
          ss.write("<p>\n")
          frag.write(ss, 2)
          ss.write("</p>\n")
        }
      else
        # issue filter against all matches
        match.each { |m|
          match2 = REXML::XPath.match(m, filter)
          ss.write("<p>\n")
          match2.each { |frag|
            ss.write("<f>\n")
            frag.write(ss, 2)
            ss.write("</f>\n")
          }
          ss.write("</p>\n")
        }
      end
      ss.write("</match>\n")
      res.body = ss.string
    end
  end

  #
  # This class defines a Servlet (subclass of HTTPServlet::AbstractServlet) for experiment properties
  #
  class SetExpPropertyServlet < HTTPServlet::AbstractServlet
    #
    # Process an incoming HTTP 'GET' request
    #
    # - req = the full HTTP 'GET' request
    # - res = the HTTP reply to send back
    #
    def do_GET(req, res)
      q = req.query
      name = q['name']
      value = q['value']
      if (name == nil || value == nil)
        raise HTTPStatus::BadRequest, "Missing sargument 'name' or 'value'"
      end
      prop = Experiment.props[name]
      if (prop == nil)
        raise HTTPStatus::BadRequest, "Undefined property '#{name}'"
      end
      prop.set(value)

      res['ContentType'] = "text"
      res.body = "Done"
    end
  end


end # End of Module
