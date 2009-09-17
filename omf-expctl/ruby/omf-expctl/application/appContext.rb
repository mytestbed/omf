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
# = applicationContext.rb
#
# == Description
#
# This class defines an Application Context.
# An Application Context holds the name, definition, bindings 
# and configurations of an application to be run on a node
# during an experiment. 
#
#
require 'omf-common/mobject'

#
# This class defines an Application Context.
# An Application Context holds the name, definition, bindings 
# and configurations of an application to be run on a node
# during an experiment. 
#
class AppContext < MObject

  attr_reader :app, :id, :bindings, :env

  def initialize(app, context)
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
  end

  #
  # Return the OML Configuration associated with this Application Context
  #
  # - nodeSet = the Node Set use when building the OML Config
  #             (optional when this method is called by the Node's State tracing)
  #
  # [Return] an XML representation of the OML configuration, or nil if no 
  #          measurement points are defined for this Application Context
  #
  def getOMLConfig(nodeSet = nil)
    if !@app.measurements.empty?
      # Build the XML configuration for the OML Client library
      # based on the measurement request of the Experiment
      # First - build the header
      omlXML = REXML::Document.new()
      el = REXML::Element.new('omlc')
      el.add_attribute("exp_id","#{Experiment.ID}")
      el.add_attribute("id","#{nodeSet}") if nodeSet != nil
      omlXML << el
      el = REXML::Element.new('collect')
      el.add_attribute("url","#{OConfig[:tb_config][:default][:oml_url]}")
      # Second - build the entry for each measurement point
      @app.measurements.each do |m|
        # add mstream configurations
	el << m.to_xml
      end
      omlXML.root << el 
      return omlXML
    else
      return nil
    end
  end

  #
  # Return the Environment configuration associated with this Application Context
  #
  # - nodeSet = the Node Set use when building the environment config
  #             (optional when this method is called by the Node's State tracing)
  #
  # [Return] an Hash containing the environment parameters
  #
  def getENVConfig(nodeSet = nil)
    unless @app.measurements.empty?
      # add OML environment
      @env['OML_SERVER'] = OConfig[:tb_config][:default][:oml_url]
      @env['OML_EXP_ID'] = Experiment.ID
      @env['OML_NAME'] = "#{nodeSet}" if nodeSet != nil
    end
    return @env
  end

  #
  # Start an Application on a given Node Set
  # This method creates and sends the Command Object to start an application 
  # on a group of nodes (resources)
  # 
  # - nodeSet = the group of nodes on which to start the application
  #
  def startApplication(nodeSet)
    debug("Starting application '#@id'")

    # Get a new Command Object and starting adding info to it
    app_cmd = Communicator.instance.getCmdObject(:EXECUTE)
    app_cmd.group = nodeSet.groupName
    app_cmd.procID = @id
    appDefinition = @app.appDefinition
    app_cmd.path = appDefinition.path

    # Add the OML info, if any...
    omlconf = getOMLConfig(nodeSet)
    app_cmd.omlConfig = omlconf if omlconf != nil

    # Add the environment info...
    app_cmd.env = getENVConfig(nodeSet)

    # Add the bindings...
    pdef = appDefinition.properties
    # check if bindings contain unknown parameters
    if (diff = @bindings.keys - pdef.keys) != []
      raise "Unknown parameters '#{diff.join(', ')}'" \
            + " not in '#{pdef.keys.join(', ')}'."
    end
    app_cmd.cmdLineArgs = appDefinition.getCommandLineArgs(@bindings, @id, nodeSet)
    
    # Ask the Communicator to send the Command Object 
    Communicator.instance.sendCmdObject(app_cmd)
  end
  
end # ApplicationContext

# a = Application['foo']
#
# mu = MutableApplication.new('#goo')
# mu.uri = "change"
# a.uri = "fail"
#
# a2 = Application['#goo']

