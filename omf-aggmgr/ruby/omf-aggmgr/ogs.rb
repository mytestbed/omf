#!/usr/bin/ruby
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
# = ogs.rb
#
# == Description
#
# This file implements a web server providing various Grid Services.
# The services themselves are dynamically loaded. Upon startup, if a YAML configuration
# exists in '/etc/omf-aggmgr/enabled' for a given Service, then that Service is loaded.
# The source code of the various services are located into sub-directories of the form
# 'ogs_serviceName'
#

require 'webrick'
require 'omf-common/mobject'
require 'omf-common/omfVersion'
require 'omf-common/servicecall'

# We need to find a better way of adding the dependencies of the
# individual services.
require 'stringio'
require 'date'
require 'rexml/document'
require 'yaml'
require 'optparse'
#####
require 'omf-aggmgr/ogs/serviceMounter'


include WEBrick

#
# Our Version Number
#
OMF_VERSION = OMF::Common::VERSION(__FILE__)
OMF_MM_VERSION = OMF::Common::MM_VERSION()
OMF_VERSION_STRING = "OMF Aggregate Manager #{OMF_VERSION}"

DEF_SEARCH_PATH = [".", "../etc/omf-aggmgr-#{OMF_MM_VERSION}", "/etc/omf-aggmgr-#{OMF_MM_VERSION}"]
DEF_CONFIG_FILE = 'omf-aggmgr.yaml'
DEF_WEB_PORT = 5012

#---------

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
  serviceClass = Class::class_eval("#{service}")
  name = serviceClass.serviceName
  path = "/#{name}"

  configFile = "#{findServiceDir}/#{configFileName}"
  MObject.debug(:gridservices, "Loading service config file '#{configFile}'")
  if (File.readable?(configFile))
    f = File.open(configFile)
    params = YAML::parse(f).transform
    f.close

    if (cfg = params[name]).nil?
      raise "Missing configuration for service '#{name}'"
    end
    serviceClass.configure(cfg)
  else
    MObject.error(:gridservices, "Service config file '#{configFile}' is not readable")
  end

  if serviceClass.respond_to?(:mount) then
    MObject.debug(:gridservices, "Mounting legacy service #{serviceClass}")
    serviceClass.mount(ServiceMounter.server(:http), path)
    # Make sure legacy HTTP services get reported in the service summary XML document
    # (see AggmgrServer#all_services_summary)
    ServiceMounter.aggmgr_server(:http).register_legacy_service_class(serviceClass)
  else
    MObject.debug(:gridservices, "Mounting service #{serviceClass}")
    ServiceMounter.mount(serviceClass)
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

  # First initialize the connection to the XMPP server, if XMPP is enabled
  xmpp_params = params[:xmpp]
  xmpp_connection = nil
  if not xmpp_params.nil?
    xmpp_connection = OMF::XMPP::Connection.new(xmpp_params[:server],
                                                xmpp_params[:user],
                                                xmpp_params[:password])
    xmpp_params[:connection] = xmpp_connection
  end

  ServiceMounter.init(params)

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
        file = "omf-aggmgr/ogs_#{name}/#{name}"
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
          MObject.debug(:gridservices, "Exception: #{ex} (#{ex.class})\n\t#{bt}")
        end
      end
    }
  end
  @stopping = false
  ["INT", "TERM"].each { |sig|
    trap(sig) {
      if not @stopping then
        ServiceMounter.stop_services
        AbstractDaemon.all_classes_instances.each do |inst|
          inst.stop
        end
        @stopping = true
      end
    }
  }
  Thread.new {
    OMF::ServiceCall::XMPP.sender_id = "aggmgr"
    OMF::ServiceCall::XMPP.set_connection(xmpp_connection)
    begin
      OMF::ServiceCall.add_domain(:type => :xmpp,
                                  :uri => xmpp_params[:server])
    rescue OMF::ServiceCall::ServiceCallException => e
      MObject.error(:gridservices, "Failed to set up service call framework: #{e}")
      bt = e.backtrace.join("\n\t")
      MObject.debug(:gridservices, "Exception:  #{e} (#{e.class})\n\t#{bt}")
    end
    ServiceMounter.start_services
  }.join
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
    configFile = "#{params[:configDir]}/#{DEF_CONFIG_FILE}"
  end
  if (File.readable?(configFile))
    MObject.debug(:gridservices, "Reading configuration file #{configFile}")
    tree = YAML::parse(File.open(configFile)).transform
    tree.each_pair {|k, v|
      if (! params.has_key?(k))
        params[k.to_sym] = v
      end
    }
  elsif (! optional)
    MObject.error('services', "Can't find config file '#{configFile}")
    return false
  else
    MObject.info('services', "Config file '#{configFile}' not readable. You may find an example file in /usr/share/doc/omf-aggmgr-#{OMF_MM_VERSION}/examples.")
  end
  return true
end

#################################
#
# Handle Command-line Options...
#
logParams = {:env => "GRID_SERVICES_LOG", :fileName => "def_gridservices_log.xml",
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
opts.on("-s", "--services NAME1,NAME2", "Services to load [load all in 'dir']") {|services|
  params[:services] = services.split(',').map {|s| s.strip }
}

opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }
opts.on_tail("-v", "--version", "Show the version") {
  puts OMF_VERSION_STRING
  exit
}

#################################
#
# Program Entry Point
#
begin
  rest = opts.parse(ARGV)

  MObject.initLog('service', nil, logParams)
  MObject.info('init', OMF_VERSION_STRING)
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
