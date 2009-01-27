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

require "handler/version"
require "handler/measurement"
require "handler/appProperty"
require "handler/appDefinition"
require "handler/property"
require "handler/omlApp"
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
  def initialize(appRef, name = idRef)
    super("app:#{appRef}")
    @appRef = appRef
    @appDefinition = AppDefinition[appRef]
    @properties = Array.new
    @measurements = Array.new
  end

  #
  # Instantiate this application for a particular
  # set of nodes (NodeSet).
  #
  # - nodeSet = the NodeSet instance to configure according to this prototype
  # - vName = Virtual name used for this app (used for state name)
  # - context = array with the values of the bindings for local parameters
  #
  def instantiate(nodeSet, vName, context)
    # Create property list
    bindings = Hash.new
    @properties.each {|p|
      # property :idref, :value, :unit, :bindingRef, :isBound
      name = p.idref
      if p.isBound
        value = context[p.bindingRef]
      else
        value = p.value
      end
      bindings[name] = value
    }
    omlUrl = OmlApp.create(self, "#{nodeSet.groupName}_#{vName}")
    # env = appDefinition.environment # bug: appDefinition.environment is shared by same type of apps in a nodeSet
    env = Hash.new
    if omlUrl != nil
      env['OML_CONFIG'] = omlUrl
      env['%OML_NAME'] = 'node%x-%y'
      if env.has_key?('LD_LIBRARY_PATH')
        env['LD_LIBRARY_PATH'] += ':/usr/lib/'
      else
        env['LD_LIBRARY_PATH'] = '/usr/lib/'
      end
    end
    nodeSet.addApplication(self, vName, bindings, env)
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
  # - vName = the virtual name of the application
  #
  def install(nodeSet, vName)
    if (rep = appDefinition.binaryRepository) == nil
      raise "Missing binary repository for '#{appDefinition.name}"
    end
    # TODO: Need to differentiate among different install methods (apt, tar)
    nodeSet.send(:INSTALL, ["proc/#{vName}", rep])
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
  # Add a measurement point to this application
  #
  # - idRef  = Reference to a measurement point
  # - filterMode = Type of OML filter - time or sample
  # - metrics = Metrics to use from measurement point
  #
  def addMeasurement(idRef, filterMode, properties = nil, metrics = nil)

    mDef = appDefinition.measurements[idRef]
    if (mDef == nil)
      raise "Unknown measurement point '#{idRef}'"
    end
    m = Measurement.new(mDef, filterMode, properties, metrics)
    @measurements += [m]
    return m
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
    m = MutableMeasurement.new(mDef)
    block.call(m)
    @measurements += [m]
    return m
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

# a = Application['foo']
#
# mu = MutableApplication.new('#goo')
# mu.uri = "change"
# a.uri = "fail"
#
# a2 = Application['#goo']

