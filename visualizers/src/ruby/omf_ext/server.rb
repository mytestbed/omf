require "set"
require "thread"
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

require 'rubygems'
require 'webrick'
require 'webrick/httputils'
require 'stringio'
require 'util/mobject'

require 'omf_ext/renderer'
require 'omf_ext/helpers'
require 'omf_ext/graph_server'

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

    #MObject.debug(:web, "Configuring internal web server: #{args.inspect}")
    @@server = HTTPServer.new(args)
#    @@server.mount("/xml", XMLServlet)
#    @@server.mount("/xpath", XPathServlet)
#    @@server.mount("/set", SetExpPropertyServlet)
    
    @@server.mount_proc('/') do |req, resp|
      include OMF::ExperimentController::Web
      opts = {:params => {}, :flash => {}, :file_name => "fooo", :exp_id => "outdoor_23004_4343_43434"}
      #resp.body = MabRenderer.render('graph/show', opts, ViewHelper)
      resp.body = MabRenderer.render('code/show', opts, ViewHelper)
    end
    
    @@server.mount('/graph/config', OMF::ExperimentController::Graph::ConfigServlet)
    @@server.mount('/graph/result', OMF::ExperimentController::Graph::TestDataServlet)
    
    @@server.mount_proc('/crossdomain.xml') do |req, res|
      res.body = %{
<cross-domain-policy>
    <allow-access-from domain="*"/>
</cross-domain-policy>
}
      res['content-type'] = 'text/xml'
    end    

    #OConfig.REPOSITORY_DEFAULT.each { |dir|
    [".."].each { |dir|
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



end # End of Module

if __FILE__ == $0
  NodeHandlerServer.start
  if true 
    mutex = Mutex.new
    blocker = ConditionVariable.new

    mutex.synchronize {
      blocker.wait(mutex)
    }
  else
    require 'irb'
    ARGV.clear
    ARGV << "--simple-prompt"
    ARGV << "--noinspect"
    IRB.start()
  end
end

