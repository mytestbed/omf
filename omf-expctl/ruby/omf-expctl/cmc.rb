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
# = cmc.rb
#
# == Description
#
# This module holds the methods used by the Node Handler to interact with 
# the CMC Services
#

module CMC
	
  # Holds the list of active nodes for this experiment
  @@activeNodes = nil

  # Syntactic sugar...
  # Return the URL of the CMC service from OConfig
  #
  def CMC.URL() 
    OConfig[:tb_config][:default][:cmc_url] 
    #OConfig.CMC_SERVICE()
  end

  #
  # Switch a given node ON
  #
  # - x = X coordinate of node
  # - y = Y coordinate of node
  #
  def CMC.nodeOn(name)
    if NodeHandler.JUST_PRINT
      puts ">> CMC: Switch on node '#{name}'"
    else
      url = "#{CMC.URL}/on?name=#{name}"
      MObject.debug("CMC", "up ", url)
      begin
        NodeHandler.service_call(url, "Can't switch on node '#{name}'")
      rescue Exception => ex
        MObject.debug("CMC", "Can't switch ON node '#{name}'", url)
      end
    end
  end

  #
  # Switch a given set of nodes ON
  #
  # - set = a String describing the set of nodes to switch ON (e.g. [[1,1],[1,2]])
  #
  def CMC.nodeSetOn(set)
    if NodeHandler.JUST_PRINT
      puts ">> CMC: Switch on nodes #{set}"
    else
      url = "#{CMC.URL}/nodeSetOn?nodes=#{set}"
      MObject.debug("CMC", "up ", url)
      NodeHandler.service_call(url, "Can't switch on nodes #{set}")
    end
  end

  #
  # Switch a given node OFF Hard
  # (i.e. similar to a push of 'power' button)
  #
  # - x = X coordinate of node
  # - y = Y coordinate of node
  #
  def CMC.nodeOffHard(name)
    if NodeHandler.JUST_PRINT
      puts "CMC: Switch of node #{name}"
    else
      url = "#{CMC.URL}/offHard?name=#{name}"
      MObject.debug("CMC", "down ", url)
      NodeHandler.service_call(url, "Can't switch off node #{name}")
    end
  end

  #
  # Switch a given node OFF Soft
  # (i.e. similar to a console call to 'halt -p' on the node)
  #
  # - x = X coordinate of node
  # - y = Y coordinate of node
  #
  def CMC.nodeOffSoft(name)
    if NodeHandler.JUST_PRINT
      puts "CMC: Switch of node #{name}"
    else
      url = "#{CMC.URL}/offSoft?name=#{name}&domain=#{OConfig.domain}"
      MObject.debug("CMC", "down ", url)
      NodeHandler.service_call(url, "Can't switch off node #{name}")
    end
  end

  #
  # Get a specified set of nodes on the default domain 
  # _Deprecated_ - Method no longer used...
  #
  def CMC.getNodes(set)
    if NodeHandler.JUST_PRINT
      puts "CMC: Get Specified Nodes For a Domain"
    else
      url = "#{CMC.URL}/getNodes?nodes=#{set}"
      MObject.debug("CMC", "up ", url)
      response = NodeHandler.service_call(url, "Can't get specified nodes")
      response.body
    end
  end

  #
  # Get a list of all nodes for the default testbed domain
  #
  # [Return] a String declaring the list of nodes (e.g. "[[1,1],[1,2]])
  #
  def CMC.getAllNodes()
    if NodeHandler.JUST_PRINT
      puts "CMC: Get All Nodes For a Domain"
    else
      url = "#{CMC.URL}/getAllNodes"
      MObject.debug("CMC", "up ", url)
      response = NodeHandler.service_call(url, "Can't get All nodes")
      response.body
    end
  end

  #
  # Get all the active nodes for the default testbed domain
  # (the list of active nodes is hold in '@@activeNodes')
  #
  def CMC.getAllActiveNodes()
    if NodeHandler.JUST_PRINT
      puts "CMC: Get All Active Nodes For a Domain"
    else
      # NOTE: We should really use 'allStatus' and parse it properly
      url = "#{CMC.URL}/allStatus?domain=#{OConfig.domain}"
      response = NodeHandler.service_call(url, "Can't get All Active nodes")
      doc = REXML::Document.new(response.body)
      @@activeNodes = {}
      doc.root.elements.each('//detail/*') { |e|
        attr = e.attributes
        name = attr['name']
        state = attr['state']
        if state.match(/^POWER/)
          @@activeNodes[name] = true
        end
      }
    end
  end

  #
  # Return true if a given node belongs to the list of active nodes
  #
  # - x = X coordinate of node
  # - y = Y coordinate of node
  #
  # [Return] true/false
  #  
  def CMC.nodeActive?(name)
    # Check if EC is running in 'Just Print' or 'Slave mode'
    # Yes - Then always say that a node is active!
    return true if NodeHandler.JUST_PRINT || NodeHandler.SLAVE
    if (@@activeNodes == nil)
      CMC.getAllActiveNodes
    end
    @@activeNodes.has_key?(name)
  end

  #
  # Switch all nodes OFF Hard
  # (i.e. similar to a push of 'power' button)
  #
  def CMC.nodeAllOffHard()
    if NodeHandler.JUST_PRINT
      puts "CMC: Switch off hard node"
    else
      url = "#{CMC.URL}/allOffHard?"
      MObject.debug("CMC", "all off HARD")
      NodeHandler.service_call(url, "Can't switch off hard nodes")
    end
  end

  #
  # Switch all nodes OFF Soft
  # (i.e. similar to a console call to 'halt -p' on the node)
  #
  def CMC.nodeAllOffSoft()
    if NodeHandler.JUST_PRINT
      puts "CMC: Switch off soft node"
    else
      url = "#{CMC.URL}/allOffSoft?domain=#{OConfig.domain}"
      MObject.debug("CMC", "up ", url)
      NodeHandler.service_call(url, "Can't switch off soft nodes")
    end
  end

  #
  # Reset a particular node
  #
  # - x = X coordinate of node
  # - y = Y coordinate of node
  #
  def CMC.nodeReset(name)
    if NodeHandler.JUST_PRINT
      puts "CMC: Reset node #{name} (#{response})"
    else
      #CMC.nodeOn(x,y)
      url = "#{CMC.URL}/reset?name=#{name}&domain=#{OConfig.domain}"
      begin
        response = NodeHandler.service_call(url, "Can't reset node #{name}")
      rescue Exception => ex
        MObject.debug("CMC", "Can't reset node #{name} ", url)
      end
    end
  end
end
