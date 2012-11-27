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
# This file defines the AbstractGroupNodeSet class 
#
require 'omf-expctl/node/nodeSet'

#
# This abstract class implements behavior for a NodeSet, which contains other NodeSets. 
# Basically this class implements a the abstract idea of a 'group of NodeSets'.
#
class AbstractGroupNodeSet < NodeSet

  #
  # This method starts all the applications associated to all the
  # NodeSets in this group
  #
  def startApplications
    debug("Start all applications")
    super
    groups.each { |g|
      debug("..... Start applications in #{g}")
      g.startApplications
    }
  end

  #
  # This method stops all the applications associated to all the
  # NodeSets in this group
  #
  def stopApplications
    debug("Stop all applications")
    super
    groups.each { |g|
      debug(".... Stop applications in #{g}")
      g.stopApplications
    }
  end

  #
  # This method powers ON all nodes in all the NodeSets in this group
  #
  def powerOn()
    groups.each { |g|
      g.powerOn
    }
  end

  #
  # This method powers OFF all nodes in all the NodeSets in this group
  # By default the nodes are being powered off softly (asked nicely to 
  # powerdown), but setting 'hard' to true the nodes are being powered 
  # off immediately. Use the hard power down with caution.
  #
  # - hard = true/false (optional, default=false)
  #
  def powerOff(hard = false)
    groups.each { |g|
      g.powerOff(hard)
    }
  end
  
  # Return all groups included in this group. If +recursive+
  # is true, also include all groups included by groups.
  # The result will include each group only once, even if it
  # appears multiple times in the crawl.
  #
  def groups()
    raise "Not implemented here" 
  end

end
