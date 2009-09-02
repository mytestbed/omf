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
#
# This class defines an Application that can be used within an
# OMF Experiment Description (ED).
# It will refer to an AppDefinition for information on the
# available parameters and measurment points
#

require "omf-expctl/version"
require "omf-expctl/application/appProperty"
require "omf-expctl/application/appDefinition"
require "omf-expctl/application/appContext"
require "omf-expctl/property"
require "omf-expctl/oml/oml_mstream"
require "rexml/document"

#
# This class defines an Application that can be used within an
# OMF Experiment Description (ED).
# It will refer to an AppDefinition for information on the
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
    appCtxt = AppContext.new(self, context)    
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
  def measure(idRef = :mandatory, opts = {}, &block)
    raise OEDLMissingArgumentException.new(:measure, :idRef) if idRef == :mandatory

    puts "TDEBUG - measure - #{idRef} - #{opts}"

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
