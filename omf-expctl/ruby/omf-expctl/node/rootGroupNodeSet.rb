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
# This file defines the RootGroupNodeSet class and its sub-class 
# DefinedGroupNodeSet
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
    super("_ALLGROUPS_")
    @nodeSelector = "*"
  end

  # Return all groups included in this group. If +recursive+
  # is true, also include all groups included by groups.
  # The result will include each group only once, even if it
  # appears multiple times in the crawl.
  #
  def groups(recursive = false)
    groups = Set.new(@@groups.values)
    if (recursive)
      groups.each do |ns|
        groups << ns.groups(true)
      end
    end
    return groups
  end

  # Return all nodes included in this group. 
  # 
  # If a +nodeSet+ is provided, nodes will be added to it 
  # otherwiste a new node set is being created
  #
  def nodes(nodeSet = Set.new)
    @@groups.each_value do |g|
      g.nodes(nodeSet)
    end
    return nodeSet
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
    groups.each {|g| sel = sel + "#{g.to_s} " }
    #@nodeSelector = "\"#{sel}\""
    @nodeSelector = "#{sel}"
  end
end
