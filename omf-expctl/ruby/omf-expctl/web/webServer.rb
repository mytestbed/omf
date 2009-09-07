#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
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
# = webServer.rb
#
# == Description
#
# This file implements a small web server to observe the status of a nodeHandler
#

require 'webrick'
require 'webrick/httputils'
require 'stringio'
require 'omf-common/mobject'

require 'omf-expctl/web/renderer'
require 'omf-expctl/web/helpers'

#require 'omf-expctl/web/dashboardServlet'
#require 'omf-expctl/web/xmlStateServlet'
#require 'omf-expctl/web/parameterServlet'
#require 'omf-expctl/web/logServlet'
#require 'omf-expctl/web/graphServlet'
#require 'omf-expctl/web/codeServlet'

include WEBrick

#
# This module implements a light WebServer based on the WEBrick library.
# This webserver is used to observe the status of the Node Handler
#
module OMF
  module ExperimentController
    module Web
#      SERVICES = [
#        Dashboard,
#        Code,
#        Graph,
#        Log,
#        State
#      ]

      @@server = nil
      @@services = []
      @@tabs = []
    
      #
      # Start a new web-server (in a new Thread) to report on the NH's status
      #
      # - port = optional, port to listen to (default=2000)
      # - args = optional, arguments for the server
      #
      def self.start(port = 2000, args = {})
    
        args[:Port] = port
    
        mimeTable = HTTPUtils::DefaultMimeTypes
        mimeTable.update({ "xsl" => "text/xml" })
        args[:MimeTypes] = mimeTable
    
#        MObject.debug(:web, "Configuring internal web server: #{args}")
        @@server = HTTPServer.new(args)
        
        
        
#        options = {:params => {}, :flash => {}, :server => self}
#        SERVICES.each { |s|
#          s.configure(self, options)
#        }
        
        tabDir = "#{File.dirname(__FILE__)}/tab"
        Dir.foreach(tabDir) {|d| 
          if d =~ /^[a-z]/
            initF = "#{tabDir}/#{d}/init.rb"
            if File.readable?(initF)
              MObject.debug(:web, "Loading tab '#{d}' (#{initF})")
              load(initF)
            end
          end
        }

        options = {:params => {}, :flash => {}, :server => self}
        services = @@services.sort {|a, b| a[0] <=> b[0] }
        services.each { |priority, serviceClass|
          serviceClass.configure(self, options)
        }

        @@server.mount_proc('/exp_id') do |req, resp|
          resp.body = Experiment.ID
        end

        @@server.mount_proc('/crossdomain.xml') do |req, res|
          res.body = %{
<cross-domain-policy>
    <allow-access-from domain="*"/>
</cross-domain-policy>
}
          res['content-type'] = 'text/xml'
        end    
        
        OConfig[:ec_config][:repository][:path].each { |rep|
          public = "#{rep}/public_html"
          if File.directory?(public)
            MObject.debug(:web, "Mounting /resource to #{public}")
            @@server.mount("/resource", HTTPServlet::FileHandler, public, true)
            break
          end
        }
    
        Thread.new {
          begin
            MObject.debug(:web, "Starting web server on port #{port}")
            @@server.start
          rescue => ex
            MObject.error(:web, "Internal web server died. #{ex}")
          end
        }
      end
      
      def self.registerService(serviceClass, priority = 999)
        @@services << [priority, serviceClass]
      end
      
      def self.mount(path, servlet, options = {})
        @@server.mount(path, servlet, options)
      end
      
      def self.addTab(key, path, options = {})
        @@tabs << options.merge({:key => key, :path => path})
      end
      
      def self.tabs
        @@tabs
      end
    
      #
      # Return the URL of this NH's webserver
      #
      # [Return] a String wih the URL
      #
      def self.url()
        addr = @@server.listeners[0].addr
	host = OConfig[:ec_config][:web][:host]
        # Check if NH is running in 'Slave' Mode or has no Host set in its config file
        if NodeHandler.SLAVE_MODE() || host == nil
           # Yes - then other entities should access NH's web server on localhost
          return "http://127.0.0.1:#{addr[1]}"
        else
          return "http://#{host}:#{addr[1]}"
        end
      end
    
      #
      # Map a given URL path to the corresponding servlet handler
      #
      # - path = the URL path to map
      # - servlet = the servlet which will handle services at that path
      #
      def self.map(path, servlet)
        @@server.mount(path, servlet)
      end
    
      #
      # Map a given URL path to a corresponding file 
      #
      # - path = the URL path to map
      # - *options = options to pass to the FileHandler HTTP Servlet
      #
      def self.mapFile(path, *options)
        @@server.mount(path, HTTPServlet::FileHandler, *options)
      end
    
      #
      # Map a given URL path to a given code-block
      #
      # - path = the URL path to map
      # - &block = the code-block which will be executed for that path
      #
      def self.mapProc(path, &block)
        @@server.mount_proc(path, &block)
      end
    
      #
      # Set the HTTP Document Root
      #
      # - path = the path to be used as the HTTP Document Root
      #
      def self.documentRoot(path)
        @@server.mount("/", HTTPServlet::FileHandler, path)
      end
    
      #
      # Stop the NH's webserver
      #
      def self.stop()
        @@server.shutdown if @@server != nil
        @@server = nil
      end
    
    
    
    
    
    end # End of Module
  end
end

