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
#
# This class defines an Application Context.
# An Application Context holds the name, definition, bindings 
# and configurations of an application to be run on a node
# during an experiment. 
#

#
# This class defines an Application Context.
# An Application Context holds the name, definition, bindings 
# and configurations of an application to be run on a node
# during an experiment. 
#

require 'omf-common/mobject'

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

    unless @app.measurements.empty?
      # add OML environment
      @env['OML_SERVER'] = OConfig[:tb_config][:default][:oml_server_url]
      @env['OML_ID'] = Experiment.ID
      @env['OML_NODE_ID'] = '%node_id'
      
      @app.measurements.each do |m|
        # add mstream configurations
      end
    end
    
    app_cmd = Communicator.instance.getCmdObject()
    app_cmd.type = :EXECUTE
    app_cmd.group = nodeSet.groupName
    app_cmd.procID = @id
    app_cmd.env = @env

    info "TDEBUG - 1 - acmd: '#{app_cmd}'"
    
    #cmd = [@id, 'env', '-i']
    #@env.each {|name, value|
    #  cmd << "#{name}=#{value}"
    #}

    appDefinition = @app.appDefinition
    #cmd << appDefinition.path
    app_cmd.path = appDefinition.path

    #info "TDEBUG - 2 - cmd: '#{cmd}'"
    
    pdef = appDefinition.properties
    # check if bindings contain unknown parameters
    if (diff = @bindings.keys - pdef.keys) != []
      raise "Unknown parameters '#{diff.join(', ')}'" \
            + " not in '#{pdef.keys.join(', ')}'."
    end
    
    #cmd = appDefinition.getCommandLineArgs(@id, @bindings, nodeSet, cmd)
    app_cmd.cmdLineArgs = appDefinition.getCommandLineArgs(@bindings, @id, nodeSet)
    
    #acmd.omlConfig = OMF::ExperimentController::OML::MStream.omlConfig(@app.measurements)
    
    #info "TDEBUG - 3 - SENDING cmd: '#{cmd.join(" ")}'"
    info "TDEBUG - 2 - SENDING acmd: '#{app_cmd}'"
    #info "TDEBUG - 3 - SENDING acmd: '#{acmd.cmdLine}'"

    #nodeSet.send(:exec, *cmd)

    # FIXME:
    # Here we should send an XML document to the NA.
    # This would have the context and also later the 
    # XML config for the OML client on the NA side
    #
    Communicator.instance.sendCmdObject(app_cmd)
    #
  end
  
end # ApplicationContext

# a = Application['foo']
#
# mu = MutableApplication.new('#goo')
# mu.uri = "change"
# a.uri = "fail"
#
# a2 = Application['#goo']

