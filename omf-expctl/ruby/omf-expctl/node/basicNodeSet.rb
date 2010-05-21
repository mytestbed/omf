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
# This file defines the class BasicNodeSet
#
require 'omf-expctl/node/nodeSet'
require 'observer'

#
# This sub-class of NodeSet represents a set of individual nodes.
#
class BasicNodeSet < NodeSet

  #
  # This method creates a new node set where the selector is a Topology object
  #
  # - groupName = optional name for specific node sets, see NodeSet's constructor.
  # - topo = optional, when defined all nodes in the given topology will be added to this NodeSet
  #
  def initialize(groupName, topo = nil)
    @topo = topo
    super(groupName)
  end

  #
  # This method adds an application which is associated with this NodeSet
  # This applications will be started when 'startApplications'
  # is called. See NodeSet::addApplication for argument details
  #
  # - appContext = the Application Context to add (AppContext). This context
  #                holds the Application name, its binding, environments,...
  #
  def addApplication(appContext)
    super(appContext)
    self.eachNode { |n|
      n.addApplication(appContext)
    }
  end

  #
  # This method executes a block of commands for every node in this NodeSet
  #
  # - &block = the block of command to execute
  #
  def eachNode(&block)
    @topo.eachNode(&block) if !@topo.nil?
  end

  #
  # This method calls inject over the nodes contained in this NodeSet.
  #
  # - seed = the initial value for the inject 'result'
  # - &block = the block of command to inject
  #
  def inject(seed = nil, &block)
    @topo ? @topo.inject(seed, &block) : seed
  end

  #
  # This method powers ON all the nodes in this NodeSet
  #
  def powerOn()
    #ns = @topo.nodeSetDecl
    # Check that EC is NOT in 'Slave Mode' - If so call CMC to switch node(s) ON
    #if !NodeHandler.SLAVE_MODE()
    #  CMC.nodeSetOn(ns)
    #end
    # Now set the state of each node to ON
    eachNode { |n|
      n.powerOn()
      if NodeHandler.JUST_PRINT
        n.checkIn(n.nodeId, '1.0', 'UNKNOWN')
        n.heartbeat(0, 0, Time.now.to_s)
      end
    }
  end

  #
  # This method powers OFF all nodes in this set 
  # By default the nodes are being powered off softly (asked nicely to 
  # powerdown), but setting 'hard' to true the nodes are being powered 
  # off immediately. Use the hard power down with caution.
  #
  # - hard = true/false (optional, default=false)
  #
  def powerOff(hard = false)
    #ns = @topo.nodeSetDecl
    #if hard
    #  CMC.nodeSetOffHard(ns)
    #else
    #  CMC.nodeSetOffSoft(ns)
    #end
    eachNode { |n| n.powerOff() }
  end

end
