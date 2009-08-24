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
# = application.rb
#
# == Description
#
# This class defines the bindings and configurations
# of an application to be run on a node
# during an experiment. It will refer to an
# AppDefinition for information on the
# available parameters and measurment points
#

require "omf-expctl/version"
#require "omf-expctl/measurement"
require "omf-expctl/appProperty"
require "omf-expctl/appDefinition"
require "omf-expctl/property"
require "omf-expctl/oml/oml_mstream"
#require "omf-expctl/omlApp"
require "rexml/document"

#
# This class defines the bindings and configurations
# of an application to be run on a node
# during an experiment. It will refer to an
# AppDefinition for information on the
# available parameters and measurment points
#

class Application < MObject

  include CreatePropertiesModule

  # Definition of application
  attr_reader :appDefinition

  # Short and longer description of the application
  #attr_reader :description

  # Specific property settings
  attr_reader :properties

  # Measurement points used and their configurations/filter
  attr_reader :measurements


  #
  # @param appRef Reference to appliciation definition
  #
  def initialize(appRef, opts = {}, &block)
    super("app:#{appRef}")
    @appRef = appRef
    @appDefinition = AppDefinition[appRef]
    @properties = Array.new
    @measurements = Array.new

    block.call(self) if block
  end

  #
  # Instantiate this application for a particular
  # set of nodes (NodeSet).
  #
  # - nodeSet = the NodeSet instance to configure according to this prototype
  # - context = hash with the values of the bindings for local parameters
  #
  def instantiate(nodeSet, context = {})
    install(nodeSet)
    appCtxt = ApplicationContext.new(self, context)    
    nodeSet.addApplication(appCtxt)
    appCtxt
  end

  #
  # Check if the application can be installed, if not it is assumed
  # to be native to image on the node's disk.
  #
  # [Return] true or false
  #
  def installable?
    d = appDefinition
    return d.aptName != nil || d.binaryRepository != nil
  end


  #
  # Install the application on a given set of nodes (NodeSet)
  #
  # - nodeSet = the NodeSet object on which to install the application
  #
  def install(nodeSet)
    if (aptName = @appDefinition.aptName) != nil
      # Install App from DEB package using apt-get 
      nodeSet.send(:APT_INSTALL, "app:#{vName}/install", aptName)
    elsif (rep = @appDefinition.binaryRepository) != nil
      # Install App from TAR archive using wget + tar 
      # We first have to mount the local TAR file to a URL on our webserver
      # ALERT: Should check if +rep+ actually exists
      url_dir="/install/#{rep.gsub('/', '_')}"
      url="#{OMF::ExperimentController::Web.url()}#{url_dir}"
      OMF::ExperimentController::Web.mapFile(url_dir, rep)
      nodeSet.send(:PM_INSTALL, "app:#{name}/install", url, '/')
    end
  end


  #
  # Install the application on a given set of nodes (NodeSet)
  #
  # - nodeSet = the NodeSet object on which to install the application
  # - vName = the virtual name of the application
  #
#  def install(nodeSet, vName)
#    if (rep = appDefinition.binaryRepository) == nil
#      raise "Missing binary repository for '#{appDefinition.name}"
#    end
#    # TODO: Need to differentiate among different install methods (apt, tar)
#    nodeSet.send(:INSTALL, ["proc/#{vName}", rep])
#  end
  
  



  #
  # Add a measurement point to this application
  #
  # - idRef  = Reference to a measurement point
  # - filterMode = Type of OML filter - time or sample
  # - metrics = Metrics to use from measurement point
  #
  def addMeasurement(idRef, filterMode, properties = nil, metrics = nil)

    error("'addMeasurement' is no longer working! Use 'measure' inside 'addApplication' block instead")
#    mDef = appDefinition.measurements[idRef]
#    if (mDef == nil)
#      raise "Unknown measurement point '#{idRef}'"
#    end
#    m = Measurement.new(mDef, filterMode, properties, metrics)
#    @measurements += [m]
#    return m
  end


  #
  # Return a measure from a given measurement point, and execute 
  # a block of command on it
  #
  # - idRef = Reference to a measurement point
  # - block = block of code to execute
  #
  def measure(idRef, &block)

    mDef = appDefinition.measurements[idRef]
    if (mDef == nil)
      raise "Unknown measurement point '#{idRef}'"
    end

    m = OMF::ExperimentController::OML::MStream.new(mDef, self, &block)
    @measurements << m
    return m
  end

  #
  # Return the application definition as XML element
  #
  # [Return] an XML element for this application
  #
  def to_xml
    a = REXML::Element.new("application")
    a.add_attribute("refid", appDefinition.uri)
#    a.add_element("description").text = description

    if @properties.length > 0
      pe = a.add_element("properties")
      @properties.each {|p|
        pe.add_element(p.to_xml)
      }
    end

    if @measurements.length > 0
      me = a.add_element("measurements")
      @measurements.each {|m|
        me.add_element(m.to_xml)
      }
    end
    return a
  end

  #
  # Return this application's reference in a String
  #
  # [Return] String
  #
  def to_s()
    @appRef
  end
  

end

class ApplicationContext < MObject
  attr_reader :app, :id
  
  def initialize(app, context)
    super()
    @id = app.appDefinition.getUniqueID
    @bindings = Hash.new
    @app = app
    
    # Create property list
    app.properties.each {|p|
      # property :idref, :value, :unit, :bindingRef, :isBound
      name = p.idref
      if p.isBound
        value = context[p.bindingRef]
      else
        value = p.value
      end
      @bindings[name] = value
    }
    @env = Hash.new
    
    # NOTE: Thta should really go into OmlApp
#    omlUrl = OmlApp.register(self)
#    if omlUrl != nil
#      @env['OML_CONFIG'] = omlUrl
#      @env['%OML_NAME'] = 'node%x-%y'
#      if @env.has_key?('LD_LIBRARY_PATH')
#        @env['LD_LIBRARY_PATH'] += ':/usr/lib/'
#      else
#        @env['LD_LIBRARY_PATH'] = '/usr/lib/'
#      end
#    end
  end

  def startApplication(nodeSet)
    debug("Starting application '#@id'")

    # With OMLv2 the collection server can be started as soon as NH is running
    # Thus we comment this line and start the OML Server in the main nodehandler.rb file
    #OmlApp.startCollectionServer
    unless @app.measurements.empty?
      # add OML environment
      @env['OML_SERVER'] = OConfig.OML_SERVER_URL
      @env['OML_ID'] = Experiment.ID
      @env['OML_NODE_ID'] = '%node_id'
      
      @app.measurements.each do |m|
        # add mstream configurations
      end
    end
    
    acmd = Communicator.instance.getAppCmd()
    acmd.group = nodeSet
    acmd.procID = @id
    acmd.env = @env
    
    cmd = [@id, 'env', '-i']
    @env.each {|name, value|
      cmd << "#{name}=#{value}"
    }
    

    appDefinition = @app.appDefinition
    cmd << appDefinition.path
    acmd.path = appDefinition.path
    
    pdef = appDefinition.properties
    # check if bindings contain unknown parameters
    if (diff = @bindings.keys - pdef.keys) != []
      raise "Unknown parameters '#{diff.join(', ')}'" \
            + " not in '#{pdef.keys.join(', ')}'."
    end
    
    cmd = appDefinition.getCommandLineArgs(@id, @bindings, nodeSet, cmd)
    acmd.cmdLine = appDefinition.getCommandLineArgs2(@bindings, @id, nodeSet)
    
    acmd.omlConfig = OMF::ExperimentController::OML::MStream.omlConfig(@app.measurements)
    
    nodeSet.send(:exec, *cmd)
    Communicator.instance.sendAppCmd(acmd)
  end
  
end # ApplicationContext

# a = Application['foo']
#
# mu = MutableApplication.new('#goo')
# mu.uri = "change"
# a.uri = "fail"
#
# a2 = Application['#goo']

