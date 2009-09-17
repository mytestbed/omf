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
# = nodeSet.rb
#
# == Description
#
# This file also defines the RootNodeSetPath class 
#
#
require 'omf-expctl/node/nodeSetPath'

#
# This class defines the Root Path, i.e. the Root NodeSetPath.
# A Root Path has additional methods specific to configuring the NodeSet itself
#
class RootNodeSetPath < NodeSetPath

  #
  # Add a new Prototype to the NodeSet associated with this Root Path
  #
  # - name = name of the Prototype to associate with the NodeSet of this Path
  # - params = optional, a Hash with the bindings to be passed on to the Prototype instance (see Prototype.instantiate)
  #
  def prototype(name, params = nil)
    debug "Use prototype #{name}."
    p = Prototype[name]
    if (p == nil)
      error("Unknown prototype '#{name}'")
      return
    end
    p.instantiate(@nodeSet, params)
  end
  
  #
  # Add a new Application to the NodeSet associated with this Root Path
  #
  # - app = Application to register
  #
  def addApplication(app, &block)
    if app.kind_of? String
      # if this is a one-off command line application
      # then create a default Application object to hold it
      debug "Implicit creation of an app instance from: #{app}"
      appInstance = Application.new(app, &block)
    #else
      # real NH-compatible application (i.e. ruby wrapper)
    #  appInstance = app
    end
    appInstance.instantiate(@nodeSet)
  end

  #
  # Trigger boot from PXE Image for the nodes in the NodeSet associated to this Root Path
  #
  # - image = PXE image to boot from. If 'image' is non-nil, then the nodes in the NodeSet will 
  #           be configured to boot from that PXE image name over the network. If 'image' is set 
  #           to 'nil' then the nodes will boot from their local disks. 
  # - imageName = optional, name of image to check for. This optional name allows a node to verify 
  #           at the time the nodes check in (i.e. after boot and NA-NH contact), if it really booted 
  #           into the right image. The image name is stored in '/.orbit_image'
  #
  def pxeImage(domain, pxeFlag)
    @nodeSet.pxeImage(domain, pxeFlag)
    #@nodeSet.pxeImage(image, imageName, domain)
  end

  #
  # Set the disk image to boot the nodes in the NodeSet associated to this Root Path.
  #
  # - image = Image to boot from. If it is set to 'nil' then the nodes boot from their local disks.
  #
  def image=(image)
    @nodeSet.image = image
  end

  #
  # Load an image onto the disk of each node in the NodeSet associated with this Root Path.
  # This assumed that the nodes previously booted via PXE over the network.
  #
  # - image = name of the disk image to load onto the nodes 
  # - domain = name of the domain of the nodes 
  #
  def loadImage(image, domain)
    @nodeSet.loadImage(image, domain)
  end
  
  #
  # Stop an Image Server after loading an image onto the disks of each node in the NodeSet of this Root Path. 
  # This assumed that the nodes previously booted via PXE over the network.
  #
  # - image = name of the disk image that was loaded onto the nodes 
  # - domain = name of the domain of the nodes 
  #
  def stopImageServer(image, domain)
    @nodeSet.stopImageServer(image, domain)
  end

  #
  # When every nodes in the NodeSet associated to this Root Path are in 'UP' state, 
  # then Execute a block of commands for everyone of them 
  #
  # - &block = the block of commands to execute
  #
  def onNodeUp(&block)
    @nodeSet.onNodeUp &block
  end

  #
  # Execute a block of commands for every nodes in the NodeSet associated to this Root Path.
  #
  # - &block = the block of commands to execute
  #
  def eachNode(&block)
    @nodeSet.eachNode(&block)
  end

  #
  # This method calls inject over the nodes contained in the NodeSet associated to this Root Path.
  #
  # - seed = the initial value for the inject 'result'
  # - &block = the block of command to inject
  #
  def inject(seed = nil, &block)
    @nodeSet.inject(seed, &block)
  end

  #
  # This method starts all Applications associated to the nodes in the NodeSet of this Root Path.
  #
  def startApplications()
    debug("Start all applications")
    @nodeSet.startApplications
  end

  #
  # This method start a given Application associated to the nodes in the NodeSet of this Root Path.
  #
  # - name = name of the Application to start
  #
  def startApplication(name = nil)
    raise OEDLMissingArgumentException.new(:group, :name) unless name
    @nodeSet.startApplication(name)
  end

  #
  # This method stops all Applications associated to the nodes in the NodeSet of this Root Path.
  #
  def stopApplications()
    debug("Stop all applications")
    @nodeSet.stopApplications
  end

  #
  # This method stops a given Application associated to the nodes in the NodeSet of this Root Path.
  #
  # - name = name of the Application to stop
  #
  def stopApplication(name)
    @nodeSet.stopApplication(name)
  end

  #
  # This method sends a message on the STDIN of a given application, which is 
  # running on the nodes in the NodeSet of this Root Path.
  #
  # - name = the name of the application to send the message to 
  # - *args = a sequence of arguments to send as a messages to this application
  #
  def sendMessage(name, *args)
    @nodeSet.send(:STDIN, "#{name}", *args)
  end
  
  #
  # This method enroll to the experiment all nodes in the NodeSet of this Root Path.
  #
  def enroll()
    @nodeSet.eachUniqueNode { |n| n.enroll() }
  end

  #
  # This method reset all nodes in the NodeSet of this Root Path.
  #
  def powerReset()
    @nodeSet.eachUniqueNode { |n| n.reset() }
  end

  #
  # This method powers ON all nodes in the NodeSet of this Root Path.
  #
  def powerOn()
    @nodeSet.eachUniqueNode { |n| n.powerOn() }
  end

  #
  # This method powers OFF all nodes in the NodeSet of this Root Path.
  # By default the nodes are being powered off softly (asked nicely to 
  # powerdown), but setting 'hard' to true the nodes are being powered 
  # off immediately. Use the hard power down with caution.
  #
  # - hard = optional, default false
  #
  def powerOff(hard = false)
    @nodeSet.eachUniqueNode { |n| n.powerOff(hard) }
  end

  #
  # This method runs a command on all nodes in the NodeSet of this Root Path.
  #
  # - cmdName = name of the executable to run. It should be a full OS path, unless it is
  #             in the default path of the Node Agents running on the nodes.
  # - args = an optional array of arguments. If an argument starts with a '%', each node 
  #             will replace placeholders such as %x, %y, or %n with their own local values. 
  # - env = an optional Hash of environment variables and their respective values. This will
  #             be set before the command is executed. Again, '%' substitution will occur
  #             on these values.
  # - &block = an optional block of commands with arity 4, which will be called whenever a 
  #             message is received from a node executing 'cmdName'. The arguments for this block 
  #             are |node, operation, eventName, message|.
  #
  def exec(cmdName, args = nil, env = nil, &block)
    @nodeSet.exec(cmdName, args, env, &block)
  end

  #
  # Return true if all nodes in the NodeSet of this Root Path are in 'UP' state.
  #
  # [Return] true or false
  #
  def up?()
    @nodeSet.up?
  end

  #
  # Return a String describing the NodeSet associated to this Root Path
  #
  # [Return] a String
  #
  def to_s
    if NodeHandler.interactive?
      @nodeSet.to_s
    else
      super()
    end
  end
end

#####################################
#
# Testing Code
#
# Create _ALL_ group
#RootGroupNodeSet.new()
if $0 == __FILE__
  MObject.initLog 'test'
#  n = NodeSet.new([1, 2..3])
#  n = NodeSet.new([1..2, 2..3])
#  n = NodeSet.new([[1..2, 2..3], [6..8, 5]])
  n = NodeSet.new([[2, 1..3], [3, [1, 3]]])
end
