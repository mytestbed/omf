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
# = moteAppContext.rb
#
# == Description
#
# This class defines a Mote Application Context.
# It behaves exactly like an Application Context but it
# overrides the startApplication method to send a special
# command to the Resource Controller
#

require 'omf-expctl/application/appContext.rb'

class MoteAppContext < AppContext

  #
  # Start a mote Application on a given Node Set
  # This method creates and sends the Command Object to start
  # a mote application on a group of nodes (resources)
  #
  # - nodeSet = the group of nodes on which to start the application
  #
  def startApplication(nodeSet)
    debug("Starting application '#@id'")
    # Get a new Command Object and starting adding info to it
    appDef = @app.appDefinition
    cmd = ECCommunicator.instance.create_message(:cmdtype => :MOTE_EXECUTE,
                                                 :target => nodeSet.groupName,
                                                 :appID => @id,
                                                 :gatewayExecutable => appDef.gatewayExecutable)
    # Add the OML info, if any...
    omlconf = getOMLConfig(nodeSet)
    cmd.omlConfig = omlconf if omlconf != nil
    # Add the environment info...
    cmd.env = ""
    getENVConfig(nodeSet).each { |k,v|
      cmd.env << "#{k}=#{v} "
    }
    # Add the bindings...
    pdef = appDef.properties
    # check if bindings contain unknown parameters
    if (diff = @bindings.keys - pdef.keys) != []
      raise "Unknown parameters '#{diff.join(', ')}'" \
            + " not in '#{pdef.keys.join(', ')}'."
    end
    cmd.cmdLineArgs = appDef.getCommandLineArgs(@bindings, @id, nodeSet).join(' ')
    # Ask the NodeSet to send the Command Object
    nodeSet.send_cmd(cmd)
  end

end # ApplicationContext


