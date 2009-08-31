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
# This file defines the RootGroupNodeSet class and its sub-class DefinedGroupNodeSet
#
require 'omf-expctl/node/abstractGroupNodeSet'

#
# This singleton class represents ALL nodes. 
# It is a group of NodeSets, which contains ALL the NodeSets
#
class RootGroupNodeSet < AbstractGroupNodeSet
  include Singleton

  #
  # This method creates this singleton 
  #
  def initialize()
    super('_ALL_')
    @nodeSelector = "*"
  end

  #
  # This method executes a block of command on ALL the groups of NodeSets
  #
  # - &block = the block of command to execute
  #
  def eachGroup(&block)
    debug("Running 'eachGroup' in RootGroupNodeSet")
    @@groups.each_value { |g|
      if g.kind_of?(BasicNodeSet)
        debug("Call #{g}")
        block.call(g)
      end
    }
  end

  #
  # This method executes a block of command on ALL the node in ALL the groups of NodeSets
  #
  # - &block = the block of command to execute
  #
  def eachNode(&block)
    #debug("Running 'each' in RootGroupNodeSet")
    @@groups.each_value { |g|
      if g.kind_of?(BasicNodeSet)
        debug("Running each for #{g}")
        g.eachNode &block
      end
    }
  end

  #
  # This method calls inject over ALL the nodes 
  #
  # - seed = the initial value for the inject 'result'
  # - &block = the block of command to inject
  #
  def inject(seed = nil, &block)
    result = seed
    @@groups.each_value { |g|
      #debug "#inject: Checking #{g}:#{g.class} (#{result})"
      if g.kind_of?(BasicNodeSet)
        #debug "#inject: Calling inject on #{g} (#{result})"
        result = g.inject(result, &block)
      end
      #debug "#inject: result: #{result}"
    }
    return result
  end

  #
  # This method powers OFF ALL the nodes
  # By default the nodes are being powered off softly (asked nicely to 
  # powerdown), but setting 'hard' to true the nodes are being powered 
  # off immediately. Use the hard power down with caution.
  #
  # - hard = true/false (optional, default=false)
  #
  def powerOff(hard = false)
    if hard
      CMC.nodeAllOffHard()
    else
      CMC.nodeAllOffSoft()
    end
    Node.each {|n|
      n.powerOff()
    }
  end

end

#
# This singleton Class represents ALL nodes that are part of a 
# defined NodeSet Group
#
class DefinedGroupNodeSet < RootGroupNodeSet 
  def initialize()
    super()
    sel = ""
    eachGroup {|g| sel = sel + "#{g.to_s} " }
    @nodeSelector = "\"#{sel}\""
  end
end
