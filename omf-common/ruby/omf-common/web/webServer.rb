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

require 'omf-common/web/renderer'
#require 'omf-common/web/helpers'

include WEBrick

#
# This module implements a light WebServer based on the WEBrick library.
# This webserver is used to observe the status of the Node Handler
#
module OMF
  module Common
    module Web

      @@server = nil
      @@available_services = []
      @@enabled_services = []
      @@tabs = []
    
      #
      # Start a new web-server (in a new Thread) to report on the EC's status
      #
      # - port = optional, port to listen to (default=2000)
      # - args = optional, arguments for the server
      #
      def self.start(port = 2000, args = {})
    

        args[:Port] = port
    
        mimeTable = HTTPUtils::DefaultMimeTypes
        mimeTable.update({ "xsl" => "text/xml" })
        args[:MimeTypes] = mimeTable
        @@server = HTTPServer.new(args)

        @@helpersClass = args[:ViewHelperClass] || OMF::Common::Web::ViewHelper
        @@commonViewDir = []
        if (tabDir = args[:TabDir])
          tabDir.each do |pkg|
            $:.each do |prefix|
              dir = "#{prefix}/#{pkg}"
              if File.directory?(dir)
                Dir.foreach(dir) do |d| 
                  if d =~ /^[a-z]/
                    initF = "#{dir}/#{d}/init.rb"
                    if File.readable?(initF)
                      MObject.debug(:web, "Loading tab '#{d}' (#{initF})")
                      load(initF)
                    end
                  end
                end
                common = "#{dir}/shared"
                if File.directory?(common)
                  @@commonViewDir << dir
                end
              end
            end
          end
        end

#        @@server.mount_proc('/exp_id') do |req, resp|
#          resp.body = Experiment.ID
#        end
          
        # To keep Flash happy
        @@server.mount_proc('/crossdomain.xml') do |req, res|
          res.body = %{
<cross-domain-policy>
    <allow-access-from domain="*"/>
</cross-domain-policy>
}
          res['content-type'] = 'text/xml'
        end    
        
        resourceDir = nil
        (resourceDirChoices = (args[:ResourceDir] || [])).each do |dir|
          if File.directory?(dir)
            resourceDir = dir
            break
          end
        end
        if resourceDir
          MObject.debug(:web, "Mounting /resource to #{resourceDir}")
          @@server.mount("/resource", HTTPServlet::FileHandler, resourceDir, true)
        else
          MObject.error(:web, "Cannot find any of the resource directories '#{resourceDirChoices.join('::')}'")
        end
      
        Thread.new do
          begin
            sleep 10 # wait a bit so that the user script can define all services requested
              
            services = @@enabled_services
            if services.empty?
              services = @@available_services.select do |opts| opts[:def_enabled] end
            else
              
            end 
            
            #puts services.inspect

            options = {
              :params => {}, 
              :flash => {}, 
              :server => self, 
              :common_view_dir => @@commonViewDir
            }
            services.sort do |a, b| a[:priority] <=> b[:priority] end.each do |sopts|
              sClass = sopts[:serviceClass]
              sClass.configure(self, options.merge(sopts))
              if (initProc = sopts[:initProc])
                initProc.call(sClass)
              end
            end
            
            MObject.debug(:web, "Starting web server on port #{port}")
            @@server.start
          rescue => ex
            MObject.error(:web, "Internal web server died. #{ex}")
            puts ex.backtrace
          end
        end
      end
      
      def self.registerService(serviceClass, opts)
        opts = opts.clone
        opts[:serviceClass] = serviceClass
        @@available_services << opts
      end
      
      def self.enableService(serviceName, opts = {}, &initProc)
        MObject.debug(:web, "Enable web service '#{serviceName}'")

        if serviceName.to_sym == :defaults
          services = @@available_services.select do |opts| opts[:def_enabled] end
          @@enabled_services.concat(services)
          return  
        end
        
        service = @@available_services.find do | sopts |
          sopts[:name] == serviceName.to_sym
        end
        if service.nil?
          MObject.warn(:web, "Unknown portal service '#{serviceName}'")
          return 
        end
        opts = opts.merge(service)
        opts[:initProc] = initProc
        @@enabled_services << opts 
      end
      
      def self.mount(path, servlet, options = {})
        @@server.mount(path, servlet, options)
      end
      
      def self.addTab(key, path, options = {})
        MObject.debug(:web, "Adding tab '#{key}'")
        @@tabs << options.merge({:key => key, :path => path})
      end
      
      def self.tabs
        @@tabs
      end
    
      #
      # Return the URL of this EC's webserver
      #
      # [Return] a String wih the URL
      #
      def self.url()
        addr = @@server.listeners[0].addr
	      host = OConfig[:ec_config][:web][:host]
        # Check if EC is running in 'Slave' Mode or has no Host set in 
        # its < file
        if NodeHandler.SLAVE || host == nil
          # Yes - then other entities should access EC's web server on 
          # localhost
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
      # Stop the EC's webserver
      #
      def self.stop()
        @@server.shutdown if @@server != nil
        @@server = nil
      end
      
      def self.helpersClass()
        @@helpersClass
      end
    
    end # End of Module
  end
end

