#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
# Copyright (c) 2004-2009 - WINLAB, Rutgers University, USA
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
#
#
# This file implememts the Testbed class. A testbed is a collection of nodes.
# The testbeds are configured from the configuration file etc/gridservices/cmc.yaml
# The configuration file specifies the testbed name, the maximum node coordinates,
# and the specifics of the node IP address for each testbed. This file too specifies
# the communicator name, the CMC IP address and the Port and these are used to 
# configure the communicators. 
# This also creates the thread to check periodic status messages.
#
#
require 'socket'
require 'observer'
require 'yaml'
require 'util/mobject'
require 'util/arrayMD'
require 'ogs_cmc/cmcCommunicator'
require 'ogs_cmc/cmcNode'
require 'util/parseNodeSet'

module CMC

  #Constants to define the access to Node Status Time
  READ_STATUS   = 1
  UPDATE_STATUS = 2
    
  #CM_MAIN_GRID     = "grid"    
  #CM_SUPPORT_GRID  = "sg"
  #CM_SANDBOX_1     = "sb1"
  #CM_SANDBOX_2     = "sb2"
  #CM_SANDBOX_3     = "sb3"
  #CM_SANDBOX_4     = "sb4"
  #CM_SANDBOX_5     = "sb5"
  #CM_SANDBOX_6     = "sb6"
  #CM_SANDBOX_7     = "sb7"
  #CM_SANDBOX_8     = "sb8"
  #CM_SANDBOX_9     = "sb9"

  # Constant to define the periodic arrival time
  # of the status messages
  CM_STATUS_MSG_ARR_TIME = 20

  # Constant to define the sleep interval of the
  # status message monitor thread
  CM_STATUS_MONITOR_SLEEP_TIME  = 60

  # Constants to identify whether nodes are active / inactive
  CM_NODE_ACTIVE   = 1
  CM_NODE_INACTIVE = 2

  #
  # A testbed is a collection of nodes which are arranged in a grid with
  # the coordinates starting at 1.
  #
  class Testbed < MObject
     include Observable

    #
    # Load testbed(s) configuration from 'yamlFile'
    #
    def Testbed.loadConfig(yamlFile)
      cfg = YAML::parse(File.open(yamlFile)).transform

      # configure communicators first
      cfg['communicators'].each {|name, comm_cfg|
	Communicator.create(name, comm_cfg)
      }

      # now the testbeds
      cfg['testbeds'].each {|name, comm_cfg|
	Testbed.create(name, comm_cfg)
      }
      return cfg['primaryIF']
    end

    #
    # Create a testbed from the parameters in the config hash
    #
    def Testbed.create(name, config)
      xMax = config['x_max']
      yMax = config['y_max']
      conv3v = config['3vStatus']
      conv5v = config['5vStatus']
      conv12v = config['12vStatus']
      comm = Communicator.find(config['communicator'])
      ipBlock = config['ip_block']
      iList = config['inactive_list']
      
      if ! (xMax && yMax && ipBlock)
	raise "Missing arguments. Require 'x_max', 'y_max', and 'ipBlock'"
      end
      p = eval(ipBlock)
      Testbed.new(name, xMax, yMax, comm, iList, conv3v, conv5v, conv12v, &p )
    end

    @@tstbdlist = Hash.new
    @@monitorThread = nil

    #
    # return an instance of a named testbed
    #
    def Testbed.[] (name) 	
      tbed = @@tstbdlist[name]      
      return tbed.kind_of?(Testbed) ? tbed : nil
    end

    #
    # loop over all testbeds
    #
    def Testbed.each(&block)	
      @@tstbdlist.each_value(&block)
    end

    attr_reader  :nodes

    #
    # Create a testbed with name 'name' and size
    # (1..xMax) x (1..yMax). Use 'communicator' for
    # communication with the nodes. The 'createIP' block
    # returns the IP address for a given x/y coordinate
    # It checks for nodes in the active list and set node
    # to active and inactive accordingly.
    #
    def initialize(name, xMax, yMax, comm, iList, conv3v, conv5v, conv12v, &createIP )
      @nodes = ArrayMD.new
      @communicator = comm
      (1..yMax).each { |y|
	(1..xMax).each { |x|
	  ipAddr = createIP.call(x, y)
	  if (iList.length != 0)
	      str = x.to_s + "," + y.to_s
	      found = false
              i = 0
              while (i < iList.length)
                 if (iList[i] == str)
                    found = true
                    break
                 end
                 i += 1
              end
	      if (found == false)
	          node = CmcNode.new(self, comm, ipAddr, x, y, CM_NODE_ACTIVE, conv3v, conv5v, conv12v)
	      else
	          node = CmcNode.new(self, comm, ipAddr, x, y, CM_NODE_INACTIVE, conv3v, conv5v, conv12v)
	      end
	  else
	      node = CmcNode.new(self, comm, ipAddr, x, y, CM_NODE_ACTIVE, conv3v, conv5v, conv12v)
          end
	  @nodes[x][y] = node
	}
      }
      @@tstbdlist[name] = self
      startMonitorThread
    end

    #
    # Check if Status Message is being received periodically.
    # If not received, then  notify observers
    #
    def checkRcvStatusMsg(node)
     	t = Time.now
	statusTime = node.readUpdtStatusTime(READ_STATUS)
	if( statusTime.to_i < (t.to_i - CM_STATUS_MSG_ARR_TIME) )
            if (node.condition != NODE_NOT_REGISTERED) 
              debug("Lost status for node ", node.getcoord , " (testbed=", node.testbed, ")")
              node.setNodeUnregistered
	      notify_observers(Time.now, node.myIp, node.myPort)
            end
	end
    end

    #
    # Monitor status of all nodes on all testbeds
    # Specifically, check is status messages are arriving periodically
    #
    def startMonitorThread
      if (@@monitorThread == nil)
	@@monitorThread = Thread.new() {
	  while (true) 
	    begin
              debug(" ------------------ STATUS MONITOR THREAD ------------------")
	      Testbed.each {|tb|
		tb.each_node { |n|
		   checkRcvStatusMsg(n)
		}
	      }
	      sleep CM_STATUS_MONITOR_SLEEP_TIME
	    rescue Exception => ex
	      warn(ex)
	    end
	  end
	}
      end
    end


    #
    # return a node  according to some criteria
    # initially x@y
    #
    def node(x, y)
      xi = x.to_i
      yi = y.to_i
      return @nodes[xi][yi]
    end

    #
    # allow to loop over all nodes in a testbed
    #
    def each_node(&block)
      @nodes.each(&block)
    end

    #
    # list all active nodes for the testbed
    #
    def getActiveNodes
        str = String.new("\n")
        self.each_node { |n|
	   if (n.nodeActiveInactive == NODE_ACTIVE)
	      str += n.getcoord
	      str += "  "
	   end
	}
	return str
    end  

    #
    # get specified nodes for a testbed
    #
    def getNodes(set)
	nlist = Array.new
        sparse = ParseNodeSet.new
        ap = sparse.safeEval(set)
	nodeSet = sparse.parseNodeSetArray(ap)
        nodeSet.each { |ncoord| 
              self.each_node { |nde| 
		 cstr = "(" + nde.getcoord + ")"
                 if (ncoord == cstr)
                      nlist.insert(-1, nde.getcoord)
                 end
              }
        }
	return nlist
    end

    #
    # list all nodes for a testbed
    #
    def getAllNodes
       nlist = Array.new
       self.each_node { |n|
         nlist.insert(-1, n.getcoord)
       }
       return nlist
    end

    #
    #
    #
    def getAllStatus
       str = String.new("")
       nodeCount = 0
       activeNodeCount = 0
       poweredOnNodeCount = 0
       self.each_node { |n|
            nodeCount += 1
            if ((n.nodeActiveInactive == NODE_ACTIVE) && (n.condition != NODE_NOT_REGISTERED))
	           activeNodeCount += 1
	    end
	    if ((n.powerStatus == "UP") && (n.condition != NODE_NOT_REGISTERED) && (n.nodeActiveInactive == NODE_ACTIVE))
	           poweredOnNodeCount += 1
	    end
	    if (n.condition == NODE_NOT_REGISTERED)
	       str += "                    <node name = 'n_#{n.xcrd}_#{n.ycrd}' x='#{n.xcrd}' y='#{n.ycrd}' state='NODE NOT AVAILABLE' />\n"
	    elsif (n.nodeActiveInactive == NODE_INACTIVE)
	       str += "                    <node name = 'n_#{n.xcrd}_#{n.ycrd}' x='#{n.xcrd}' y='#{n.ycrd}' state='NODE NOT ACTIVE' />\n"
	    elsif (n.powerStatus == "UP")
	       str += "                    <node name = 'n_#{n.xcrd}_#{n.ycrd}' x='#{n.xcrd}' y='#{n.ycrd}' state='POWERON' #{n.getStatusComponent}/>\n"
	    else
	       str += "                    <node name = 'n_#{n.xcrd}_#{n.ycrd}' x='#{n.xcrd}' y='#{n.ycrd}' state='POWEROFF' #{n.getStatusComponent}/>\n"
	    end
       }
       nstatus = "<nodeCount>#{nodeCount}</nodeCount>\n"
       nstatus += "             <activeNodeCount>#{activeNodeCount}</activeNodeCount>\n"
       nstatus += "             <poweredOnNodeCount>#{poweredOnNodeCount}</poweredOnNodeCount>\n"
       nstatus += "             <detail>\n"
       nstatus += str
       nstatus += "             </detail>"
       return nstatus
    end

   #
   #
   #
   def setNodesOn(set)
        sparse = ParseNodeSet.new
        ap = sparse.safeEval(set)
	nodeSet = sparse.parseNodeSetArray(ap)
        nodeSet.each { |ncoord| 
              self.each_node { |nde| 
		 cstr = "(" + nde.getcoord + ")"
                 if (ncoord == cstr)
                      nde.nodeSetOn
                 end
              }
        }
   end

   #
   #
   #
   def setNodesOffHard(set)
        sparse = ParseNodeSet.new
        ap = sparse.safeEval(set)
	nodeSet = sparse.parseNodeSetArray(ap)
        nodeSet.each { |ncoord| 
              self.each_node { |nde| 
		 cstr = "(" + nde.getcoord + ")"
                 if (ncoord == cstr)
                      nde.nodeSetOffHard
                 end
              }
        }
   end

   #
   #
   #
   def setNodesOffSoft(set)
        sparse = ParseNodeSet.new
        ap = sparse.safeEval(set)
	nodeSet = sparse.parseNodeSetArray(ap)
        nodeSet.each { |ncoord| 
              self.each_node { |nde| 
		 cstr = "(" + nde.getcoord + ")"
                 if (ncoord == cstr)
                      nde.nodeSetOffSoft
                 end
              }
        }
   end

   #
   #
   #
   def setNodesReset(set)
        sparse = ParseNodeSet.new
        ap = sparse.safeEval(set)
	nodeSet = sparse.parseNodeSetArray(ap)
        nodeSet.each { |ncoord| 
              self.each_node { |nde| 
		 cstr = "(" + nde.getcoord + ")"
                 if (ncoord == cstr)
                      nde.nodeSetReset
                 end
              }
        }
   end

   #
   #
   #
   def setNodesUpdateEnable(set)
        sparse = ParseNodeSet.new
        ap = sparse.safeEval(set)
	nodeSet = sparse.parseNodeSetArray(ap)
        nodeSet.each { |ncoord| 
              self.each_node { |nde| 
		 cstr = "(" + nde.getcoord + ")"
                 if (ncoord == cstr)
                      nde.nodeSetUpdateEnable
                 end
              }
        }
   end

   #
   #
   #
   def setNodesUpdateDisable(set)
        sparse = ParseNodeSet.new
        ap = sparse.safeEval(set)
	nodeSet = sparse.parseNodeSetArray(ap)
        nodeSet.each { |ncoord| 
              self.each_node { |nde| 
		 cstr = "(" + nde.getcoord + ")"
                 if (ncoord == cstr)
                      nde.nodeSetUpdateDisable
                 end
              }
        }
   end

   #
   #
   #
   def setNodesIdentify(set)
        sparse = ParseNodeSet.new
        ap = sparse.safeEval(set)
	nodeSet = sparse.parseNodeSetArray(ap)
        nodeSet.each { |ncoord| 
              self.each_node { |nde| 
		 cstr = "(" + nde.getcoord + ")"
                 if (ncoord == cstr)
                      nde.nodeSetIdentify
                 end
              }
        }
   end

   #
   #
   #
   def setNodesHostEnroll(set)
        sparse = ParseNodeSet.new
        ap = sparse.safeEval(set)
	nodeSet = sparse.parseNodeSetArray(ap)
        nodeSet.each { |ncoord| 
              self.each_node { |nde| 
		 cstr = "(" + nde.getcoord + ")"
                 if (ncoord == cstr)
                      nde.nodeSetHostEnroll
                 end
              }
        }
   end

   #
   #
   #
   def nodeSetNodeInactive(set)
        sparse = ParseNodeSet.new
        ap = sparse.safeEval(set)
	nodeSet = sparse.parseNodeSetArray(ap)
        nodeSet.each { |ncoord| 
              self.each_node { |nde| 
		 cstr = "(" + nde.getcoord + ")"
                 if (ncoord == cstr)
                      nde.setNodeInactive
                 end
              }
        }
   end

   #
   #
   #
   def nodeSetNodeActive(set)
        sparse = ParseNodeSet.new
        ap = sparse.safeEval(set)
	nodeSet = sparse.parseNodeSetArray(ap)
        nodeSet.each { |ncoord| 
              self.each_node { |nde| 
		 cstr = "(" + nde.getcoord + ")"
                 if (ncoord == cstr)
                      nde.setNodeActive
                 end
              }
        }
   end

end

   #
   #
  if $0 == __FILE__
    MObject.initLog('cmcTest')

    Testbed.loadConfig("../../../../etc/gridservices/cmc.yaml")

  end

end
# module
