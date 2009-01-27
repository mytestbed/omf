#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
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
# = stdlib.rb 
#
# == Description
#
# This Ruby file contains various general declarations, which the NH will load 
# before the user's experiment file
#
# These declarations implement the process that loop, check and wait that all the 
# required nodes are UP, before proceeding with the remaining of the experiment
#

# Define some properties that we will use in this 
defProperty('resetDelay', 210, "Time to wait before assuming that node didn't boot")
defProperty('resetTries', 1, "Number of reset tries before declaring node dead")
# keeps track of how many times a node has been reset
ResetCount = {}

# 
# This declaration calls the 'everyNS' loop defined in handlerCommand.rb
# This declared bloc will be executed for all the existing node sets ('*') every 10sec
# This loop will stop when the bloc returns 'false', which will happen when all the nodes
# are UP
#
everyNS('*', 10) { |ns|

  # First check if we are done with adding node in that experiment
  # If not, we skip the checks and loop again in 10sec
  if NodeSet.frozen?
    # Yes, we are done adding nodes...
    nodesDown = []
    nodeCnt = 0
    # For each node in this Node Set, check if it is UP
    # Check that for 'resetDelay' time, if no sucess, reset the node
    # Do only 'resetTries' number of resets before giving up on a node
    ns.eachNode { |n|
      nodeCnt += 1
      if ! n.isUp
        nodesDown << n
        poweredAt = n.poweredAt
        if (poweredAt.kind_of?(Time))
          startupDelay = Time.now - poweredAt
          if (startupDelay > Experiment.property('resetDelay').value)
            count = ResetCount[n] = (ResetCount[n] || 0) + 1
            if (count <= prop.resetTries.value)
              MObject.info('stdlib', "Resetting node ", n)
              n.reset()
            else
              MObject.warn('stdlib', "Giving up on node ", n)
              Topology.removeNode(n.x, n.y)
            end
          end
        end
      end
    }
    # Check the number of nodes still not UP...
    nodesDownCnt = nodesDown.length
    if nodesDownCnt > 0
      MObject.info('stdlib', "Waiting for nodes (Up/Down/Total): #{nodeCnt-nodesDownCnt}/#{nodesDownCnt}/#{nodeCnt}",
        " - (still down: ", nodesDown[0..2].join(','),")")
    end
    # Stop looping if all the ndoes are UP!
    nodesDownCnt > 0
  else
    # We have not finished adding nodes to this experiment, loop and check again in 10sec
    true
  end
}
