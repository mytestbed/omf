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
# = handlerCommands.rb
#
# == Description
#
# This file contains the definition of all the commands that 
# the experimenters can use in their scripts. All these commands'
# are understood by the NH, which will interpret them in order to
# stage the experiments
#


#
# Define an experiment property which can be used to bind
# to application and other properties. Changing an experiment
# property should also change the bound properties, or trigger
# commands to change them.
#
# - name = name of property
# - defaultValue = default value for this property
# - description = short text description of this property
#
def defProperty(name, defaultValue, description)
  Experiment.defProperty(name, defaultValue, description)
end

#
# Return the context for setting experiment wide properties
#
# [Return] a Property Context
#
def prop
  return PropertyContext
end

#
# Define a new topology. The topology can
# be described by an optionally array declaration, or
# with a block with the newly created topology as
# single argument.
#
# - refName = the name for this new topology
# - nodeArray = optional, an array that defines the node to add in this topology
# - &block = optional, a code-block containing commands that define this topology
#
# [Return] the newly created Topology object
#
def defTopology(refName, nodeArray = nil, &block)
  if (nodeArray != nil && !nodeArray.kind_of?(Array))
    raise "Topology description. Expected array but got '#{nodeArray}'"
  end
  topo = Topology.create(refName, nodeArray)
  if (! block.nil?)
    block.call(topo)
  end
  topo
end


#
# Define a new prototype. The supplied block is
# executed with the new Prototype instance
# as a single argument.
#
# - refName = reference name for this property
# - name = optional, short/easy to remember name for this property
# - &block = a code-block to execute on the newly created property
#
def defPrototype(refName, name = nil, &block)
  p = Prototype.create(refName)
  p.name = name
  block.call(p)
end

#
# Deprecated, 'defGroup' should be used instead
#
def defNodes(groupName, selector = nil, &block)
  MObject.warn "'defNodes()' is deprecated - please use defGroup() instead"
  defGroup(groupName, selector, &block)
end

#
# Define a set of nodes to be used in the experiment.
# This can either be a specific declaration of nodes to
# use, or a set combining other sets.
#
# - groupName = name of this group of nodes
# - selector = optional, either a String refering to the name of an existing Topology, 
#              or an Array explicitly describing the nodes to include in this group 
# - &block = a code-block with commands, which will be executed on the nodes in this group
#
# [Return] a RootNodeSetPath object referring to this new group of nodes
#
def defGroup(groupName, selector = nil, &block)

  if (NodeSet[groupName] != nil)
    raise "Node set '#{groupName}' already defined. Choose different name."
  end

  if selector.kind_of?(ExperimentProperty)
    selector = selector.value
  end

  if (selector != nil)
    if selector.kind_of?(String)
      if ((topo = Topology[selector]) == nil)
        raise "Unknown topology '#{selector}' in node set '#{groupName}'"
      end
      ns = BasicNodeSet.new(groupName, topo)
    elsif selector.kind_of?(Array)
      if selector[0].kind_of?(String)
        ns = GroupNodeSet.new(groupName, selector)
      else
        tname = "-:topo:#{groupName}"
        topo = Topology.create(tname, selector)
        ns = BasicNodeSet.new(groupName, topo)
      end
    elsif
      raise "Unknown node set declaration '#{selector}: #{selector.class}'"
    end
  else
    ns = BasicNodeSet.new(groupName)
  end

  return RootNodeSetPath.new(ns, nil, nil, block)
end


#
# Evaluate a code-block in the context of a previously defined
# group of nodes.
#
# - groupName = the name of the group of nodes
# - &block = the code-block to evaluate/execute on the group of nodes
#
# [Return] a RootNodeSetPath object referring to the group of nodes
#
def group(groupName, &block)
  ns = NodeSet[groupName.to_s]
  if (ns == nil)
    raise "Undefined node set '#{groupName}'"
  end
  return RootNodeSetPath.new(ns, nil, nil, block)
end

#
# Deprecated, 'group()' should be used instead
#
def nodes(groupName, &block)
  MObject.warn "'nodes()' is deprecated - please use group() instead"
  group(groupName, &block)
end

#
# Evaluate a code-block over all nodes in all groups of the experiment.
#
# - &block = the code-block to evaluate/execute on all the groups of nodes
#
# [Return] a RootNodeSetPath object referring to all the groups of nodes
#
def allGroups(&block)
  NodeSet.freeze
  ns = DefinedGroupNodeSet.instance
  return RootNodeSetPath.new(ns, nil, nil, block)
end

#
# Deprecated, 'AllGroups()' should be used instead
#
def allNodes(&block)
  MObject.warn "'allNodes()' is deprecated - please use allGroups() instead"
  allGroups(&block)
end

#
# Evalute block over all nodes in an the experiment, even those
# that do not belong to any groups
#
# - &block = the code-block to evaluate/execute on all the nodes
#
# [Return] a RootNodeSetPath object referring to all the nodes
#
def allNodes!(&block)
  NodeSet.freeze
  ns = RootGroupNodeSet.instance
  return RootNodeSetPath.new(ns, nil, nil, block)
end

#
# Periodically perform 'nodeTest' on all nodes in 'nodesSelector'
# and execute block ONCE if all tests evaluate to true.
# The interval between checks is given by 'interval' in seconds.
#
# - nodesSelector = the name of the group of nodes to test
# - nodeTest = the test to perform on the nodes
# - interval = the interval at which to perform the test (in sec, default=5)
# - &block = the code-block to execute/evaluate against the nodes when the test returns 'true'
#
def whenAll(nodesSelector, nodeTest, interval = 5, &block)
  ns = NodeSet[nodesSelector]
  if ns == nil
    raise "WhenAll: Unknown node set '#{nodesSelector}"
  end
  Thread.new(ns) { |ns|
    while true
      begin
        res = false
        isUp = ns.up?
        #MObject.debug("whenAll::internal", "Checking ", ns, " up?: ", isUp)
        if isUp
          res = ns.inject(true) { |flag, node|
            if flag
              match = node.match(nodeTest)
              #match.each{|e| e.write($stdout, 2)}
              flag = (match != nil && match.length > 0)
              MObject.debug("whenAll::internal", "Not true for ", node) if !flag
              #p "FLAG: #{flag}"
            end
            flag
          }
        end
        if res
          MObject.info("whenAll", nodesSelector, ": '", nodeTest, "' fires")
          begin
            RootNodeSetPath.new(ns, nil, nil, block)
    rescue ServiceException => sex
      begin
        if (sex.response)
    MObject.error('run', "ServiceException: #{sex.message}\n\t#{sex.response.body}")
        else
    MObject.error('run', "ServiceException: #{sex.message}")
        end
      rescue Exception
      end
          rescue Exception => ex
            bt = ex.backtrace.join("\n\t")
            MObject.error("whenAll", "Exception: #{ex} (#{ex.class})\n\t#{bt}")
          end
          # done
          break
        end
        Kernel.sleep(interval)
      rescue Exception => ex
        bt = ex.backtrace.join("\n\t")
        puts "Exception: #{ex} (#{ex.class})\n\t#{bt}"
      end
    end
  }
end

#
# Execute 'block' when all nodes report to be up.
#
# - &block = the code-block to execute/evaluate against the nodes in 'up' state 
#
def whenAllUp(&block)
  whenAll("*", "status[@value='UP']", &block)
end

#
# Execute 'block' when all nodes report all applications installed.
#
# - &block = the code-block to execute/evaluate against the 'installed' nodes 
#
def whenAllInstalled(&block)
  whenAll("*", "apps/app/status[@value='INSTALLED.OK']", &block)
end

#
# Periodically execute 'block' every 'interval' seconds until block
# returns nil.
#
# - name = the name for this periodic action
# - interval = interval at which to execute the action (in sec, default=60) 
# - initial = optional, any initial conditions that will be passed to the Thread running this code-block 
# - &block = the code-block to periodically execute/evaluate. This periodic task is stopped when block returns 'nil'
#
def every(name, interval = 60, initial = nil, &block)
  Thread.new(initial) { |context|
    while true
      Kernel.sleep(interval)
      MObject.debug("every(#{name}): fires - #{context}")
      begin
        if ((context = block.call(context)) == nil)
          break
        end
      rescue Exception => ex
        bt = ex.backtrace.join("\n\t")
        MObject.error("every(#{name})", "Exception: #{ex} (#{ex.class})\n\t#{bt}")
      end
    end
    MObject.debug("every(#{name}): finishes")
  }
end

#
# Periodically execute 'block' against a group of nodes every 'interval' seconds 
#
# - nodesSelector = the name of the group of nodes 
# - interval = interval at which to execute the action (in sec, default=60) 
# - &block = the code-block to periodically execute/evaluate
#
def everyNS(nodesSelector, interval = 60, &block)
  ns = NodeSet[nodesSelector]
  if ns == nil
    raise "Every: Unknown node set '#{nodesSelector}"
  end
  path = RootNodeSetPath.new(ns)
  Thread.new(path) { |path|
    while true
      Kernel.sleep(interval)
      MObject.debug("every", nodesSelector, ": fires")
      begin
        if ! (path.call &block)
          break
        end
      rescue Exception => ex
        bt = ex.backtrace.join("\n\t")
        MObject.error("whenAll", "Exception: #{ex} (#{ex.class})\n\t#{bt}")
      end
    end
    MObject.debug("every", nodesSelector, ": finishes")
  }
end

#
# Return the appropriate antenna (set)
#
# - x = x coordinate of the antenna 
# - y = y coordinate of the antenna 
# - precision = optional, how close to (x,y) does the antenna really have to be (default=nil)
#
# [Return] an Antenna object
#
def antenna(x, y, precision = nil)
  a = Antenna[x, y, precision = nil]
  if (a == nil)
    raise "Undefined antenna within #{x}@#{y}"
  end
  return a
end

#
# Wait for some time before issuing more commands
#
# - time = Time to wait in seconds
#
def wait(time)
  info "Request from Experiment Script: Wait for #{time}s...."
  Kernel.sleep time
end

#
# Debugging support:
# print an information message to the 'stdout' & the logfile of NH
#
# - *msg = message to print
#
def info(*msg)
  MObject.info('exp', *msg)
end

#
# Debugging support:
# print an warning message to the 'stdout' & the logfile of NH
#
# - *msg = message to print
#
def warn(*msg)
  MObject.warn('exp', *msg)
end

#
# Debugging support:
# print an error message to the 'stdout' & the logfile of NH
#
# - *msg = message to print
#
def error(*msg)
  MObject.error('exp', *msg)
end

#
# Reporting/Debugging support:
# print the XML tree of states/attributs of NH
#
def ls(xpath = nil)
  root = NodeHandler::ROOT_EL
  if xpath.nil?
    root.write($stdout, 2)
  else
    res = REXML::XPath.match(root, xpath)
    res.inject(true) {|isFirst, el|
      puts "\n--------------------------" unless isFirst
      el.write($stdout, 2)
      false
    }
  end
  '' # supress additional output from IRB
end

#
# Reporting/Debugging support:
# print the XML tree of states/attributs of NH
#
def ls2(xpath = nil)
  root = NodeHandler::ROOT_EL
  if xpath.nil?
    res = NodeHandler::ROOT_EL.children
  else
    res = REXML::XPath.match(root, xpath)
  end

  res.each do |e|
    attrs = e.attributes
    as = ""
    if attrs.size > 0
      res = []
      attrs.each_attribute do |a|	
        res << "#{a.name}=#{a.value}"
      end
      as = " (#{res.join(' ')}) "
    end
    puts "#{e.name}#{as} #{e.text}" 	
  end
  '' # supress additional output from IRB
end
