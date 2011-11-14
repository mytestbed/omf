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
# This file defines the GroupNodeSet class 
#
require 'omf-expctl/node/abstractGroupNodeSet'

#
# This class implements a Group of NodeSets.
# It is the usuable sub-class of AbstractGroupNodeSet
#
class GroupNodeSet < AbstractGroupNodeSet

  #
  # This method creates a new group NodeSet, where the selector is an
  # array of names of existing node sets.
  #
  # - groupName = optional name for this group of NodeSet 
  # - selector = expression that identifies the node sets to include in 
  #   this group of NodeSets (e.g. ["group1","group2"])
  #
  def initialize(groupName, selector)
    if (selector == nil)
      raise "Need to specifiy array of names of existing NodeSets"
    end
    @nodeSets = Set.new
    add(selector)
    super(groupName)
  end

  #
  # This method executes a block of commands for every NodeSet in this group of NodeSets
  #
  # - &block = the block of command to execute
  #
  def eachGroup(&block)
    debug("Running 'eachGroup' in GroupNodeSet")
    @nodeSets.each { |g|
       block.call(g)
    }
  end

  #
  # This method adds an application which is associated with every NodeSets in this group
  # This application will be started when 'startApplications'
  # is called. See NodeSet::addApplication for argument details
  #
  def addApplication(app)
    super(app)
    eachGroup { |g|
      # inform all enclosed groups, but do not request another install
      g.addApplication(app)
    }
  end

  #
  # This method executes a block of commands for every node in every NodeSets in this group of NodeSets
  #
  # - &block = the block of command to execute
  #
  def each(&block)
    @nodeSets.each { |s|
      s.each &block
    }
  end

  #
  # This method calls inject over the NodeSets contained in this group.
  #
  # - seed = the initial value for the inject 'result'
  # - &block = the block of command to inject
  #
  def inject(seed = nil, &block)
    result = seed
    @nodeSets.each { |s|
      result = s.inject(result, &block)
    }
    return result
  end

  private

  #
  # This method adds the NodeSets described by 'selector' as a new NodeSet in this group of NodeSets
  #
  # - selector = an Array describing the new NodeSets to add to this group, 
  #              (e.g. ["group1", "group2"]
  # 
  def add(selector)
    if selector.kind_of?(Array)
      # Check if each name in the 'selector' refer to a valid NodeSet
      # If so, then add this NodeSet to this new group of NodeSet
      selector.each { |name|
        s = NodeSet[name]
        if s == nil
          raise "Unknown NodeSet (name '#{name}')"
        end
        s.add_observer(self)
        @nodeSets.add(s)
      }
    elsif selector.kind_of?(ExperimentProperty)
      s = selector.value
      add(s)
    else
       raise "Unrecognized node set selector type '#{selector.class}'."
    end
  end
end
