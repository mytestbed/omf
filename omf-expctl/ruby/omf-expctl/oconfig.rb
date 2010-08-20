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
# = oconfig.rb
#
# == Description
#
# This file defines the OConfig module
#
#
require 'observer'

#
# This module implements the methods used by the Experiment Controller
# to acces both its own configuration parameters, and the parameters 
# which are specific to the testbed(s)
#
# Usage examples to query OConfig:
#
#   OConfig[:ec_config][:communicator]
#
module OConfig
  
  @@domainName = nil
  @@configName = nil  
  @@observers = []
  @@loadHistory = []
  @allNodes = []
  
  #
  # Return the value of a given configuration parameter
  #
  # - key = the name of the configuration parameter to query
  #
  # [Return] the value of that parameter (nil if unknown parameter)
  #
  def self.[](key)
    res = @@config[key]
    warn("Configuration parameter '#{key}' is nil") if res.nil?
    res
  end
  def self.[]=(key, value)
    @@config[key] = value
  end

  #
  # NOTE: After integration of new AM service call, this should send a query
  # to the Slice's root node to ask for the presence of all the resources
  # involved in this experiment's slice.
  #
  # Return the default path(s) to the repository(ies) 
  #
  # [Return] a path string
  #
  def self.ALL_NODES()
    return @allNodes
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
  # Return the URL of the RESULT service
  #
  # [Return] an URL string
  #
  def self.RESULT_SERVICE()
    #return self.getConfigFromInventoryByKey('result_url')
    # TODO: This is most likely looking in the wrong place
    @@config[:ec_config][:result][:url]
  end

  #
  # Return the URL of the RESULT service
  #
  # [Return] an URL string
  #
  def self.CMC_SERVICE()
    @@config[:ec_config][:cmc][:url]
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
    @@config[:ec_config][:repository][:path].each { |dir|
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
  def self.load(uri, evalRuby = false, default_ext = '.rb')
    # Find the file to load...
    file = self.findFile(uri)
    if file == nil
      # Could not find it, try again but append +default_ext+ to the URI 
      file = self.findFile(uri + default_ext)
    end
    if file == nil
      # Still can't find it, give up.
      raise IOError, "Cannot find the file to load '#{uri}' at the path(s)"+
                     "[#{@@config[:ec_config][:repository][:path].join(', ')}]"
    end
    # Found the file, read it and optionally evaluate the ruby code inside
    str = File.new(file).read()
    if evalRuby
      begin
        eval(str, OMF::ExperimentController::CmdContext.instance._binding(),
             uri)
      rescue Exception => ex
        if ex.kind_of?(OEDLException)
          # Remove the 1st backtrace line (i.e. the file implementing the cmd)
          bt = ex.backtrace 
          bt.shift 
          ex.set_backtrace(bt)
          raise ex
        else
          # Repackage any other raised exception as an OEDL exception
          msg = ex.to_s
          if ex.kind_of?(NameError) # Remove context pointing to CmdContext
            a = msg.split(' ') ; a.delete_at(a.size-1) ;a.delete_at(a.size-1) 
            msg = a.join(' ') ; msg << " in '#{uri}'"
          end
          e = OEDLException.new("(#{ex.class}) #{msg}")
          e.set_backtrace(ex.backtrace)
          raise e
        end
      end
      #require file
    end
    state = {:uri => uri, :location => file, :content => str, 
             :mime_type => '/text/ruby'}
    @@loadHistory << state
    @@observers.each { |proc|
      proc.call(:load, state)
    }

    [str, 'text/ruby']
  end
  
  #
  # Return an array where each entry describes a script loaded in the order they were loaded.
  # Each entry is a hash with the following keys:
  #
  #  * :uri - Script URI 
  #  * :location - Where it was fetched from
  #  * :content - Content of loaded script
  #  * :mime_type - Mime type of script
  #
  def self.getLoadHistory()
    @@loadHistory    
  end

  #
  # Similar to 'load' method, but use the external loading function, which may 
  # be defined in the EC config file. This loading method is obsolete, and 
  # should be removed.
  # See 'load' for more info on 'uri' and 'evalRuby' arguments.
  #
  def self.loadExternal(uri, evalRuby = false)
    getProc('load').call(uri, evalRuby)
  end

  #
  # Retrieve and return a piece of code from the Node Handler configuration 
  # file as a Proc. This method is obsolete, as we have adopted a design
  # where the EC get most of its config from the Inventory service. Thus it 
  # should be removed.
  #
  # - name = name identifying the code block to retrieve in the EC config file
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
  # Set the domain for this Experiment Controller
  #
  # - domain =  Name of the domain where this EC is running
  #
  def self.domain=(domain)
    @@domainName = domain
  end
  
  #
  # Return the domain of this Experiment
  #
  def self.domain()
    @@domainName 
  end
  
  #
  # Set the configuration section for this Experiment Controller
  #
  # - config =  Name of the configuration section
  #
  def self.config=(config)
    @@configName = config
  end
  
  #
  # Return the configuration section of this Experiment
  #
  def self.config()
    @@configName 
  end

  #
  # Initialize this new OConfig using the information in an
  # YAML configuration file. 
  #
  # - configFile = path to the configuration file
  #
  def self.init_from_yaml(configFile)
    @@procs = {}
    require 'yaml'
    # Check that config file exists and has correct format
    if (!File.readable?(configFile))
      raise "Can't find configuration file '#{configFile}'"
    end
    h = YAML::load_file(configFile)
    if ((c = h[:econtroller]) == nil)
      raise "Missing ':econtroller' root in '#{configFile}'"
    end
    # Now initialize this new OConfig
    self.init(c[:config])
  end
  
  #
  # Initialize this new OConfig using the information in an
  # existing YAML hash. 
  #
  # - opts = a YAML hash
  #
  def self.init(opts)
    @@config = Hash.new    
    # Load the 'default' EC configuration parameters from the YAML hash
    @@config[:ec_config] = opts[:default]
    if @@config[:ec_config] == nil
      raise "OConfig - ':default:' config entry missing in configuration file."
    end
    # Load domain-specific override parameters, if any
    if @@configName != nil
      if ((override = opts[@@configName.intern]) != nil)
        @@config[:ec_config].merge!(override)
      else
        warn "OConfig - No entry in configuration file for config "+
             "'#{@@configName}'. Using ':default:' config."
      end
    end
    # get the domain name from the config file
    if ((@@domainName = @@config[:ec_config][:domain]) == nil)
      raise "OConfig - Domain (':domain:') missing in config file."
    end
  end
  
  def self.add_observer(&proc)
    @@observers << proc
  end
  
end
