#!/usr/bin/ruby
#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2008 - WINLAB, Rutgers University, USA
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
# = ogs.rb
#
# == Description
#
# This file implements a web server providing various Grid Services.
# The services themselves are dynamically loaded. Upon startup, if a YAML configuration
# exists in '/etc/gridservices2/enabled' for a given Service, then that Service is loaded.
# The source code of the various services are located into sub-directories of the form
# 'ogs_serviceName'
#

require 'webrick'
require 'log4r'
require 'util/mobject'

# We need to find a better way of adding the dependencies of the
# individual services.
require 'stringio'
#require 'util/websupp'
#require 'util/arrayMD'
#require 'util/parseNodeSet'
#require 'net/http'
require 'date'
require 'rexml/document'
#require 'external/mysql'
#require 'webrick/httpstatus'
#require 'ldap'
require 'yaml'
require 'optparse'
#####
require 'ogs/gridService'

# PACKAGING HACK -
# Hack to force services to be included in the distribution - need to remove that
# - When packaging, set the following to 'true'
# - When running GS2, set the following to 'false'
if true then
require 'ogs_frisbee/frisbee'
require 'ogs_pxe/pxe'
require 'ogs_omlServer/omlServer'
require 'ogs_oml2Server/oml2Server'
require 'ogs_inventory/inventory'
require 'ogs_result/result'
# Two CMC alternatives:
# - 'cmc', which is the full CMC implementation (currently under dev/debug)
# - 'cmcStub', which is just a stub to temporary make the NH happy on the NICTA 
#    platform which currently does not have CMC functionalities
#
# Both will be installed with the package.
# BUT only ONE should be ENABLED at any given time! (using symlinks in '/etc/enabled')
require 'ogs_cmcStub/cmcStub' # use the stub 
require 'ogs_cmc/cmc' # use real cmc
end

include WEBrick
include Log4r

$VERSION = "@VERSION@"
REVISION = "$Revision: $".split(":")[1].chomp("$").strip
VERSION_STRING = "Orbit Services Version #{$VERSION} (#{REVISION})"

DEF_SEARCH_PATH = [".", "../etc/gridservices2", "/etc/gridservices2"]
DEF_CONFIG_FILE = 'gridservice_cfg.yaml'
DEF_WEB_PORT = 5012

#---------

@@registeredServices = {}
@@serviceDir = nil

#
# Register a new Service to this Server
#
# - service = the name of the GridService class to register
# - configFileName = the path/name of the config file for this Service
#
def register(service,configFileName)
  # We now derive the service Class from the string 'service'
  # 'service' is the service name given by the calling run() method
  # This new design allows us to avoid calling 'register' from the service .rb file
  #
  # name = service.serviceName
  # path = "/#{name}"
  # @@registeredServices[path] = service
  # service.mount(@@server, path)
  serviceClass = Class::class_eval("#{service}")
  name = serviceClass.serviceName
  path = "/#{name}"
  @@registeredServices[path] = serviceClass
  serviceClass.mount(@@server, path)

  # configFile = "#{findServiceDir}/#{name}.yaml"
  configFile = "#{findServiceDir}/#{configFileName}"
  MObject.debug(:register, "Loading service config file '#{configFile}'")
  if (File.readable?(configFile))
    #params = YAML::load(File.open(configFile))
    params = YAML::parse(File.open(configFile)).transform

    if (cfg = params[name]).nil?
      raise "Missing configuration for service '#{name}'"
    end
    # service.configure(params[name])
    serviceClass.configure(cfg)
  else
    MObject.error("Service config file '#{configFile}' is not readable")
  end
end

#
# Main Execution Loop for this Server
#
# - params = a Hash containing the configuration parameters for this Server
#
def run(params)
  @@params = params
  # Find directory containing service implementations
  if ((serviceDir = findServiceDir(params)) == nil)
    exit -1
  end
  $: << "#{params[:configDir]}/lib"
  MObject.debug(:gridservices, "Library path: #{$:.join(':')}")

  if (! loadConfig(params))
    exit -1
  end

  startServer(params)

  if ((services = params[:services]) != nil)
    services.each { |name|
      begin
        file = "#{name}/#{name}"
        MObject.info(:gridservices, "Loading #{name} service module")
        if (! require(file))
          MObject.error(:gridservices, "Failed loading #{name} service module")
        end
      rescue => ex
        MObject.error(:gridservices, "Failed loading #{name} service module: #{ex}")
      end
    }
  else
    MObject.debug('gridservices', "Loading all available services from #{serviceDir}")
    Dir.foreach(serviceDir) {|filename|
      if (filename =~ /\.yaml$/) then
        name = filename.split('.')[0]
        MObject.info(:gridservices, "Loading #{name} service module")
        file = "ogs_#{name}/#{name}"
        begin
          require(file)
          # Building the class name out of the config file name
          # This new design allows us to avoid calling 'register' from the service .rb file
          serviceClassName = name
          serviceClassName[0] = (serviceClassName[0,1]).upcase # .capitalize not good, it changes the all string
          serviceClassName = serviceClassName + "Service"
          # Register the service
          register(serviceClassName, filename)
        rescue Exception => ex
          MObject.error(:gridservices, "Failed loading #{file}: #{ex}")
          bt = ex.backtrace.join("\n\t")
          MObject.debug("Exception: #{ex} (#{ex.class})\n\t#{bt}")
        end
      end
    }
  end

  @@server.start
end

#
# Start the Web Server, which will accept requests for Services
# 
# - params = a Hash containing the configuration parameters for this Web Server
#
def startServer(params)
  @@server = HTTPServer.new(
    :Port => params[:webPort] || DEF_WEB_PORT,
    :Logger => Logger.new("#{MObject.logger.fullname}::web"),
    :RequestHandler => lambda {|req, resp|
      beforeRequestHook(req, resp)
    }
  )
  trap("INT") { @@server.shutdown }

  path = File.dirname(params[:configDir]) + "/favicon.ico"
  @@server.mount("/favicon.ico", HTTPServlet::FileHandler, path) {
    raise HTTPStatus::NotFound, "#{path} not found."
  }
  @@server.mount_proc('/') {|req, res|
    res['Content-Type'] = "text/xml"
    body = [%{<?xml version='1.0'?><serviceGroups>}]
    @@registeredServices.each {|path, service|
      info = service.info
      name = service.serviceName
      body << "<serviceGroup path='#{path}' name='#{name}'><info>#{info}</info></serviceGroup>"
    }
    body << "</serviceGroups>"
    res.body = body.to_s
  }
end

#
# This method is searching for an 'enabled', or 'available' directory in search path
# and return its full path.
#
# - params = a Hash containing the configuration parameters for this Web Server
#
# [Return] the full path to the Service Directory, or 'nil' if no path is found
#
def findServiceDir(params = @@params)
  if (@@serviceDir != nil)
    return @@serviceDir
  end
  searchPath = (params[:configDir] || ENV['GRID_SERVICES_DIR'] || DEF_SEARCH_PATH).to_a
  ["enabled", "available"].each {|dir|
    searchPath.each { |configDir|
      path = "#{configDir}/#{dir}"
      if File.directory?(path)
        params[:serviceDir] = path
        params[:configDir] = configDir
        @@serviceDir = path
        return path
      end
    }
  }
  MObject.error('services', "Can't find service directory in '#{searchPath.join(':')}")
  return nil
end

#
# Load the configuration file for this Server. It is assumed to be in the directory 
# above the ':serviceDir' if not specifically specified on the command line.
#
# - params = a Hash containing the configuration parameters for this Web Server
#
def loadConfig(params)
  configFile = params[:configFile]
  optional = false
  if (configFile == nil)
    optional = true
    configFile = "../#{params[:serviceDir]}/#{DEF_CONFIG_FILE}"
  end
  if (File.readable?(configFile))
    YAML::load(File.open(configFile)).each {|k, v|
      if (! params.has_key?(k))
        params[k.to_sym] = v
      end
    }
  elsif (! optional)
    MObject.error('services', "Can't find config file '#{configFile}")
    return false
  end
  return true
end

#
# Do some pre-conditions before processing an incoming request. 
# Obsolete, this code is not used anymore... shall we remove it?
#
def beforeRequestHook(req, resp)
  q = req.query
  q['domain'] ||= 'default'
#  domain = req.query['domain']
#  q['peerdomain'] = Websupp.getPeerSubDomain(req)
#  address = req.peeraddr[2]
#  ip = Websupp.getAddress(address.rstrip)
#  
#  index = ip.rindex(".")
#  ip = ip.slice(0..(index-1))
#  index = ip.rindex(".")
#  ip = ip.slice(0..(index-1))
#  if domain == nil || domain == ""
#    domain = subDomain
#  end
#  
#  req.query['domain'] = domain
#  q['peerip'] = ip
end


#################################
#
# Handle Command-line Options...
#
logParams = {:env => "GRID_SERVICE_LOG", :fileName => "def_gridservices_log.xml",
  :searchPath => DEF_SEARCH_PATH}
params = {}

opts = OptionParser.new
opts.banner = "Usage: services [options]"

opts.on("-c", "--config FILE", "File containing general configuration files [#{DEF_CONFIG_FILE}]") {|file|
  params[:configFile] = file
}
opts.on("-d", "--dir DIRECTORY", "Directory containing gridservices definitions") {|dir|
  params[:configDir] = dir
}
opts.on("--log FILE", "File containing logging configuration information [#{logParams[:fileName]}]") {|file|
  logParams[:configFile] = file
}
opts.on("-p", "--port PORT_NO", "Port to start web server on [#{DEF_WEB_PORT}]") {|port|
  params[:webPort] = port.to_i
}
opts.on("-s", "--services NAME1,NAME2", "Services to load [load all in 'dir']") {|services|
  params[:services] = services.split(',').map {|s| s.strip }
}

opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }
opts.on_tail("-v", "--version", "Show the version") {
  puts VERSION_STRING
  exit
}

#################################
#
# Program Entry Point 
#
begin
  rest = opts.parse(ARGV)

  MObject.initLog('service', nil, logParams)
  MObject.info('init', VERSION_STRING)
  run(params)
rescue SystemExit => err
  exit
rescue Exception => ex
  begin
    bt = ex.backtrace.join("\n\t")
    puts "Exception: #{ex} (#{ex.class})\n\t#{bt}"
  rescue Exception
  end
  exit -1
end
