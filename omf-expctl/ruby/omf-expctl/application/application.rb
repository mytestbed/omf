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

require "omf-common/omfVersion"
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
  
  # The names for the tables in the OML database are constructed by 
  # combining an application sepcific prefix and a measurement 
  # stream specific identifier separated by '_' 
  attr_accessor :omlPrefix


  #
  # @param appRef Reference to appliciation definition
  #
  def initialize(appRef, opts = {}, &block)
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
    appCtxt = AppContext.new(self, context)    
    nodeSet.addApplicationContext(appCtxt)
    install(nodeSet, appCtxt.id)
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
    return d.debPackage != nil || d.appPackage != nil || d.rpmPackage != nil
  end

  #
  # Install the application on a given set of nodes (NodeSet)
  #
  # - nodeSet = the NodeSet object on which to install the application
  # - appID = unique application ID from the App Context
  #
  def install(nodeSet, appID)
    if (debPackage = @appDefinition.debPackage) != nil
      # Install App from DEB package using apt-get 
      nodeSet.send(ECCommunicator.instance.create_message(
                                  :cmdtype => :APT_INSTALL,
                                  :appID => "#{appID}/install",
                                  :package => debPackage))

    elsif (rpmPackage = @appDefinition.rpmPackage) != nil
      # Install App from RPM package using apt-get 
      nodeSet.send(ECCommunicator.instance.create_message(
                                  :cmdtype => :RPM_INSTALL,
                                  :appID => "#{appID}/install",
                                  :package => rpmPackage))
                                  
    elsif (rep = @appDefinition.appPackage) != nil
      # Install App from TAR archive using wget + tar 
      if File.exists?(rep)
        # We first have to mount the local TAR file to a URL on our webserver
        url_dir="/install/#{rep.gsub('/', '_')}"
        url="#{OMF::Common::Web.url()}#{url_dir}"
        OMF::Common::Web.mapFile(url_dir, rep)
      elsif rep[0..6]=="http://"
        # the tarball is already being served from somewhere
        url=rep
      else
        raise OEDLIllegalArgumentException.new(:defApplication,:appPackage,nil,"#{rep} is not a valid filename or URL") 
      end
      nodeSet.send(ECCommunicator.instance.create_message(
                                  :cmdtype => :PM_INSTALL,
                                  :appID => "#{appID}/install",
                                  :image => url,
                                  :path => "/"))
    end
  end

  #
  # Return an existing Measurement Point (MP) for this application, 
  # and execute a block of command on it
  #
  # Usage example:
  #   otg.measure('udp_out', :interval => 5) do |mp|
  #      mp.metric('myMetrics', 'seq_no' )
  #   end
  #
  # - idRef = Reference to a measurement point, this is the MP reference
  #           as defined by the application developer
  # - opts = a comma-separated list of key => value options for this MP
  # - block = block of code to execute
  #
  def measure(name = :mandatory, opts = {}, &block)
    raise OEDLMissingArgumentException.new(:measure, :name) if name == :mandatory

    mDef = appDefinition.measurements[name]
    if (mDef == nil)
      raise "Unknown measurement point '#{name}'"
    end
    m = OMF::ExperimentController::OML::MStream.new(name, @appRef, opts, self, &block)
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
    #a.add_element("description").text = description

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
  
  #
  # _Deprecated_ - Use measure(...) instead
  #
  def addMeasurement(idRef, filterMode, properties = nil, metrics = nil)
    raise OEDLIllegalCommandException.new(:addMeasurement) 
  end

end
