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
# = oconfig.rb
#
# == Description
#
# This file defines the OConfig module
#
#

#
# This module implements the methods used by NH to acces both its own configuration 
# parameters, and the parameters which are specific to a given testbed
#
module OConfig

  #
  # Return the value of a given configuration parameter
  #
  # - key = the name of the configuration parameter to query
  #
  # [Return] the value of that parameter (nil if unknown parameter)
  #
  def self.[](key)
    res = @@config[key]
    if res.nil?
      warn("Configuration parameter '#{key}' is nil")
    end
    res
  end

  #
  # Return the URL of the Inventory service
  #
  # [Return] an URL string
  #
  def self.INVENTORY_SERVICE()
    self['inventory']['url']
  end

  #
  # Query the Inventory service for the value of a configuration parameter 
  # related to a given testbed
  #
  # - configKey = the name of the configuration parameter to query
  #
  # [Return] the value of that parameter, raise an error if unknown parameter
  #
  def self.getConfigFromInventoryByKey(configKey)

    # Check if NH is running in 'Slave' mode. If so, then this NH is actually running
    # directly on a node/resource and will only be responsible for orchestrating the part
    # of the experiment which is specific to this node/resource. Thus config parameters
    # are also specific (most would be turned to 'localhost' and local node ID)
    if NodeHandler.SLAVE_MODE
      return nil 
    end
    # Test if the XML configuration blurb is empty
    if (@@configFromInventory == nil)
      # Yes, then retrieve all the testbed-specific configuration parameters from the Inventory
      url = "#{OConfig.INVENTORY_SERVICE}/getConfig?&domain=#{OConfig.GRID_NAME}"
      response = NodeHandler.service_call(url, "Can't get config '#{OConfig.GRID_NAME}' from INVENTORY")
      @@configFromInventory = REXML::Document.new(response.body)
    end 
    # Get the required specific configuration value
    configValue = nil
    @@configFromInventory.root.elements.each("/CONFIG/#{configKey}") { |e|
      configValue = e.get_text.value
    }
    if (configValue == nil)
      @@configFromInventory.root.elements.each('/ERROR') { |e|
        error "OConfig - No config found for key: #{configKey} - val: #{e.get_text.value}"
        raise "OConfig - #{e.get_text.value}"
      }
    else
      return configValue
    end
  end

  #
  # Return the maximum X coordinate for a given testbed
  #
  # [Return] x coordinate
  #
  def self.X_MAX()
    return eval(self.getConfigFromInventoryByKey('x_max')) # use eval to return an int
  end

  #
  # Return the maximum Y coordinate for a given testbed
  #
  # [Return] y coordinate
  #
  def self.Y_MAX()
    return eval(self.getConfigFromInventoryByKey('y_max')) # use eval to return an int
  end

  #
  # Return the default path(s) to the repository(ies) 
  #
  # [Return] a path string
  #
  def self.REPOSITORY_DEFAULT()
    self['repository']['path']
  end

  #
  # Return the URL of the PXE service
  #
  # [Return] an URL string
  #
  def self.PXE_SERVICE()
    return self.getConfigFromInventoryByKey('pxe_url')
  end

  #
  # Return the URL of the CMC service
  #
  # [Return] an URL string
  #
  def self.CMC_URL()
    return self.getConfigFromInventoryByKey('cmc_url')
  end

  #
  # Return the URL of the OML service
  #
  # [Return] an URL string
  #
  def self.OML_SERVICE()
    return self.getConfigFromInventoryByKey('oml_url')
  end

  #
  # Return the host address for the host running the OML server
  #
  # [Return] an host address
  #
  def self.OML_HOST()
    return self.getConfigFromInventoryByKey('oml_host')
  end

  #
  # Return the Port of the host running the OML server
  #
  # [Return] port number
  #
  def self.OML_PORT()
    return self.getConfigFromInventoryByKey('oml_port')
  end

  #
  # Return the host address for the host running the Node Handler.
  # NodeAgents will use the numerical IP address returned here to connect
  # to the machine running the NodeHandler, in order to retrieve the OML defs
  # (in XML, and generated by NH). These OML defs are used by the NAs' applications
  # Thus, this returns the control IP address (reachable by NAs) of the NH's machine
  # 
  # [Return] an host address
  #
  def self.NODE_HANDLER_HOST()
    return self.getConfigFromInventoryByKey('oml_localhost')
  end

  #
  # Return the URL of the Frisbee service
  #
  # [Return] an URL string
  #
  def self.FRISBEE_SERVICE()
    return self.getConfigFromInventoryByKey('frisbee_url')
  end

  #
  # Return the default disk identifier that should be used to load/save images
  #
  # [Return] a disk identifier (e.g. '/dev/hda')
  #
  def self.DEFAULT_DISK()
    return self.getConfigFromInventoryByKey('frisbee_default_disk')
  end

  #
  # Return the name of the testbed on which this experiment will run
  #
  # [Return] a testbed name (string)
  #
  def self.GRID_NAME()
    @@gridName
  end

  #
  # Find a file at a given URI and return it
  #
  # - uri = URI for the file to find
  #
  # [Return] the file or nil if it does not exist at the given URI
  #
  def self.findFile(uri)
    path = [ uri.split(':').join('_')]
    postfix = '/' + uri.split(':').join('/')
    self.REPOSITORY_DEFAULT().each { |dir|
      path << dir + postfix
    }
    file = path.inject(nil) { |found, p|
      if found == nil && File.readable?(p)
        found = p
      end
      found
    }
    return file
  end

  #
  # Load the file at a given URI and return its body as well as its
  # mime type.
  #
  # Two different mime types are supported:
  # * 'text/xml': The object representation is in XML
  # * 'text/ruby' : The object is described in ruby syntax
  #
  # - uri = URI of the file to load
  # - evalRuby = If true evaluate the ruby code inside the file before returning
  # 
  # [Return] the text content of the file, with its mimeType
  #
  def self.load(uri, evalRuby = false)

    # Find the file to load...
    file = self.findFile(uri)
    if file == nil
      # Could not find it, try again but append '.rb' to the URI 
      file = self.findFile(uri+'.rb')
    end
    if file == nil
      # Still can't find it, give up.
      raise IOError, "Can't find '#{uri}' in any of '#{self.REPOSITORY_DEFAULT().join(', ')}'"
    end
    # Found the file, read it and optionally evaluate the ruby code inside
    str = File.new(file).read()
    if evalRuby
      require file
    end
    [str, 'text/ruby']
  end

  #
  # Similar to 'load' method, but use the external loading function, which may be defined 
  # in the NH config file. This loading method is obsolete, and should be removed.
  # See 'load' for more info on 'uri' and 'evalRuby' arguments.
  #
  def self.loadExternal(uri, evalRuby = false)
    getProc('load').call(uri, evalRuby)
  end

  #
  # Retrieve and return a piece of code from the Node Handler
  # configuration file as a Proc. This method is obsolete, as we have adopted a design
  # where the NH get most of its config from the Inventory service. Thus it should be removed.
  #
  # - name = name identifying the code block to retrieve in the NH config file
  # 
  # [Return] the retrieved code block.
  #
  def self.getProc(name)
    if (@@procs[name] == nil)
      if ((code = self[name]) == nil)
        raise "Undefined code segment '#{name}' in config file"
      end
      begin
        @@procs[name] = eval("lambda { #{code} }")
      rescue Exception => ex
        MObject.fatal('oconfig', "Exception while eval proc '#{name}': ", ex)
      end
    end
    @@procs[name]
  end


  #
  # Load the NH configuration file. 
  #
  # - configFile = path to the configuration file
  #
  def self.init(configFile)
    @@procs = {}
    require 'yaml'
    # Check that config file exists and has correct format
    if (!File.readable?(configFile))
      raise "Can't find configuration file '#{configFile}'"
    end
    h = YAML::load_file(configFile)
    if ((c = h['nodehandler']) == nil)
      raise "Missing 'nodehandler' root in '#{configFile}'"
    end
    # First set the testbed name or try to 'guess' it
    if ((@@gridName = Experiment.domain).nil?)
      n = nil
      if ((n = c['testbed']['default']['name']) == nil)
        IO.popen('hostname -d') {|f| n = f.gets.split('.')[0] }
      end
      @@gridName = n
    end
    # Then load the 'default' configuration parameters
    @@config = c['testbed']['default']
    # Finally load testbed-specific override parameters, if any
    if ((override = c['testbed'][@@gridName]) != nil)
      @@config.merge!(override)
    end
    # Init the config info from Inventory... this will be loaded later.
    @@configFromInventory = nil
  end
end
