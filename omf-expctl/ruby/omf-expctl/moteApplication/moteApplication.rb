#
# Copyright (c) 2006-2010 National ICT Australia (NICTA), Australia
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
# = moteApplication.rb
#
# == Description
#
#
# This class defines an application for motes that can be 
# used within an OMF Experiment Description (ED).
# It will refer to a moteAppDefinition for information on the
# available parameters and measurment points.
# It is a subclass of Application. Most attributes
# and methods are used as in the Application class 

require 'omf-expctl/application/application'
require 'omf-expctl/moteApplication/moteAppDefinition'
require 'omf-expctl/moteApplication/moteAppContext'
require 'digest/md5'

class MoteApplication < Application

  #
  # @param appRef Reference to appliciation definition
  #
  def initialize(appRef, opts = {}, &block)
    @appRef = appRef
    @appDefinition = MoteAppDefinition[appRef]
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
    appCtxt = MoteAppContext.new(self, context)    
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
    return d.appPackage != nil 
  end

  #
  # Install the application on a given set of nodes (NodeSet)
  #
  # - nodeSet = the NodeSet object on which to install the application
  #
  def install(nodeSet, appID)

    if (rep = @appDefinition.appPackage) != nil

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
                                  :cmdtype => :MOTE_INSTALL,
                                  :appID => "#{appID}/install",
                                  :image => url,
                                  :path => ".",
                                  :hashkey => Digest::MD5.hexdigest(File.read(rep)),
                                  :moteExecutable => @appDefinition.moteExecutable,
                                  :gatewayExecutable => @appDefinition.gatewayExecutable,
                                  :moteType => @appDefinition.moteType,
                                  :moteOS => @appDefinition.moteOS
                                  ))
    end
  end
end
