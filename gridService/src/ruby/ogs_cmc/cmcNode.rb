#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
# Copyright (c) 2004-2008 - WINLAB, Rutgers University, USA
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
# This file implements the Node class. The Node class stores all information
# about a node. 
#
require 'util/mobject'
require 'monitor'
module CMC

    #
    # Constants to define the various node states. These are not part of 
    # the CM-CMC message protocol but are used by the CMC to keep track 
    # of the node conditions. 
    #

    NODE_REGISTERED            = 1
    NODE_NOT_REGISTERED        = 2
    NODE_POWERED_UP            = 3
    NODE_POWERED_UP_PENDING    = 4
    NODE_POWERED_DOWN          = 5
    NODE_POWERED_DOWN_PENDING  = 6
    NODE_IDENTIFY              = 7
    NODE_IDENTIFY_REQUEST      = 8
    NODE_RESET		       = 9
    NODE_ENABLE                = 10
    NODE_DISABLE               = 11
    NODE_HOST_ENROLL           = 12
    NODE_INACTIVE	       = 13
    NODE_ACTIVE		       = 14

    # Commands from CMC to CM and replies from CM to CMC
    CM_CMD_POWER_UP	             = 0x03
    CM_CMD_POWER_UP_REPLY	     = 0x83
    CM_CMD_RESET		     = 0x04
    CM_CMD_RESET_REPLY		     = 0x84
    CM_CMD_POWER_DOWN_SOFT	     = 0x05		
    CM_CMD_POWER_DOWN_SOFT_REPLY     = 0x85		
    CM_CMD_IDENTIFY_NODE             = 0x06
    CM_CMD_IDENTIFY_NODE_REPLY       = 0x86
    CM_CMD_UPDATE_ENABLE             = 0x08
    CM_CMD_UPDATE_ENABLE_REPLY       = 0x88
    CM_CMD_UPDATE_DISABLE            = 0x09
    CM_CMD_UPDATE_DISABLE_REPLY      = 0x89
    CM_CMD_POWER_DOWN_HARD	     = 0x0a		
    CM_CMD_POWER_DOWN_HARD_REPLY     = 0x8a		
    CM_CMD_HOST_ENROLL		     = 0x0b
    CM_CMD_HOST_ENROLL_REPLY	     = 0x0c

class CmcNode < ::MObject

   attr_reader :ipaddr
   attr_reader :nodeType
   attr_reader :testbed
   attr_reader :statusTime
   attr_reader :myIp
   attr_reader :myPort
   attr_reader :version
   attr_reader :condition  
   attr_reader :type
   attr_reader :status
   attr_reader :xcrd
   attr_reader :ycrd
   attr_reader :mac0
   attr_reader :mac1
   attr_reader :mac2
   attr_reader :mac3
   attr_reader :nodeActiveInactive
   attr_reader :powerStatus
   attr_reader :f3vconv
   attr_reader :f5vconv
   attr_reader :f12vconv

   @@ip2node = Hash.new


   #
   # Initialize the CMC Node
   # 
   def initialize(testbed, communicator, myIp, x, y, actInact, f3vconv, f5vconv, f12vconv)
     @f3vconv = f3vconv.to_f
     @f5vconv = f5vconv.to_f
     @f12vconv = f12vconv.to_f
     @status = Array.new
     statusTime = Time.now
     @testbed = testbed
     @communicator = communicator
     @@ip2node[myIp] = self
     @condition = NODE_NOT_REGISTERED
     @xcrd = x
     @ycrd = y
     @powerStatus = "DOWN"
     @nlock = Monitor.new
     @ptwt_lock = Monitor.new
     @stmsg_lock = Monitor.new
     if (actInact == CM_NODE_INACTIVE)
        @nodeActiveInactive = NODE_INACTIVE
     else
        @nodeActiveInactive = NODE_ACTIVE
     end
     @mac0 = "00:00:00:00:00:00"
     @mac1 = "00:00:00:00:00:00"
     @mac2 = "00:00:00:00:00:00"
     @mac3 = "00:00:00:00:00:00"
   end

   # returns the node with the specified
   # ip address
   def CmcNode.fromIP(ip)
     return @@ip2node[ip]
   end

   # return the coordinates of the node
   def getcoord
     return (xcrd.to_s + ',' + ycrd.to_s)
   end

   #
   # The CM periodically sends a status message. Only the 
   # 'timeStamp' and the 'condition' should change.
   #
   # timeStamp - Time the message was sent (CM time)
   # myIp - The CM's IP
   # myPort - The port at which the CM listens for commands
   # version - The CM's firmeware version
   # condition - Node condition flags (explained above)
   # type - Type of node:
   #	  - GRID_NODE    = 0x01
   #      - SUPPORT_NODE = 0x02
   #	  - SANDBOX_NODE = 0x03
   # status - status[0] -> 3.3v, status[1] -> 5v, 
   #        - status[2] -> 12v, status[3] -> temperature
   #
   def updateStatus(myIp, myPort, version, ipaddr, 
   		    nodeType, condition, status,
		    mac0, mac1, mac2, mac3)

     @stmsg_lock.synchronize {
     	@nodeType = nodeType
     	@updatedTime = Time.now 
     	@myIp = myIp 
     	@myPort = myPort 
     	@version = version
     	@condition = condition
     	@status = status 
     	@ipaddr = ipaddr
     	@mac0 = mac0
     	@mac1 = mac1
     	@mac2 = mac2
     	@mac3 = mac3
	if (condition == NODE_POWERED_UP)
	  @powerStatus = "UP"
	end
	if ( condition == NODE_POWERED_DOWN )
	   @powerStatus = "DOWN"
	end
     }
   end

   #
   # This method is an interface for thread synchronization between
   # the PROCESS_MESSAGE thread and the WEB_MESSAGE threads.
   # It synchronizes access to the "condition" variable.
   #
   def updateCondition(condition)
      @ptwt_lock.synchronize {
         @condition = condition
         if ( condition == NODE_POWERED_UP )
	   @powerStatus = "UP"
	 end
	 if ( condition == NODE_POWERED_DOWN )
	   @powerStatus = "DOWN"
	 end
      } 
   end

   def readCondition
      @ptwt_lock.synchronize {
         return @condition
      }
   end

   #
   # This method is an interface for thread synchronozation between
   # the STATUS MONITOR thread and the PROCESS MESSAGE thread
   # It synchronizes access to the "statusTime" variable.
   #
   def readUpdtStatusTime(operation)
      @nlock.synchronize {
        if (operation == READ_STATUS)
            return @statusTime
        end
        if (operation == UPDATE_STATUS)
	    @statusTime = Time.now
            return @statusTime
        end 
      }
   end

   #
   # Function for Switching on a node. This command is initiated by the user.
   # If the node is registered, then the CMC sends the command to the CM and 
   # updates the node status to NODE_POWERED_UP_PENDING. On subsequent  
   # successful receipt of a status message from the node, the status is 
   # updated to NODE_POWERED_UP depending on the parameters of the cmStatus
   # field. If the node is not registered, then an exception is raised.
   # A delay of 0.001 seconds to avoid the current surge. On succes, the 
   # node LED is turned ON and and ACK will come back to the CMC. If the node
   # is already POWERED_UP, then a reset followed by an identify is done. This
   # is because the reset will cause the node to be in its initial state and the
   # identify will cause the LED to blink. This is to take care of a CMC bug.
   #
   def on

       if ( @nodeActiveInactive == NODE_INACTIVE )
         raise "Node Not Active, No Operation Allowed"
       end
       if ( readCondition == NODE_NOT_REGISTERED )
       	   warn("Command Processing Error, Node Not Registered")
           raise "Node Not Registered for Testbed"

       elsif ( readCondition == NODE_POWERED_UP )
           #@communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_RESET, @nodeType)
           updateCondition(NODE_POWERED_UP_PENDING)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_IDENTIFY_NODE, @nodeType)
       else
           updateCondition(NODE_POWERED_UP_PENDING)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_POWER_UP, @nodeType)
	   sleep(0.02)
       end
   end

   #
   # Function for switching on all the nodes.  Only the nodes that have been registered 
   # will be switched on. The  unregistered nodes will be ignored. Same as the previous
   # function in other respects.  On success, LEDs of the nodes will be turned ON and 
   # and ACK will come back to the CMC.
   #
   def allOn
       if (@nodeActiveInactive == NODE_INACTIVE)
          return
       end
       if ( (readCondition == NODE_NOT_REGISTERED) )
	   return 
       elsif ( readCondition == NODE_POWERED_UP )
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_RESET, @nodeType)
           updateCondition(NODE_POWERED_UP_PENDING)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_IDENTIFY_NODE, @nodeType)
       else
	   updateCondition(NODE_POWERED_UP_PENDING)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_POWER_UP, @nodeType)
	   sleep(0.01)
       end
   end

   def nodeSetOn
       allOn
   end

   #
   # Function for Gracefully Switching off a node. This command is initiated 
   # by the user. If the node is registered, then the CMC sends the command 
   # to the CM and updates the node status to NODE_POWERED_DOWN_PENDING. On 
   # subsequent  successful receipt of a status message from the node, the 
   # status is updated to NODE_POWERED_DOWN depending on the parameters of 
   # the cmStatus field. If the node is not registered, then an exception is 
   # raised.  A delay of 0.001 seconds to avoid the current surge. On succes, 
   # the node LED is turned OFF and an ACK will come to the CMC. This commands 
   # initiates a graceful shutdown.
   #
   def offSoft
       if ( @nodeActiveInactive == NODE_INACTIVE )
         raise "Node Not Active, No Operation Allowed"
       end
       if ( readCondition == NODE_NOT_REGISTERED )
       	   warn("Command Processing Error, Node Not Registered")
           raise "Node Not Registered for Testbed"
       elsif ( readCondition == NODE_POWERED_UP )
	   updateCondition(NODE_POWERED_DOWN_PENDING)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_POWER_DOWN_SOFT, @nodeType)
	   sleep(0.01)
       end
   end

   #
   # Function for gracefully switching off all the nodes.  Only the nodes that have been 
   # registered will be switched off. The  unregistered nodes will be ignored. Same as 
   # the previous function in other respects.  On success, LEDs of the nodes will be turned OFF
   # and ACKs will come from all these nodes.
   #
   def allOffSoft
       if (@nodeActiveInactive == NODE_INACTIVE)
          return
       end
       if ( readCondition == NODE_NOT_REGISTERED )
            return
       elsif ( readCondition == NODE_POWERED_UP )
	   updateCondition(NODE_POWERED_DOWN_PENDING)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_POWER_DOWN_SOFT, @nodeType)
	   sleep(0.01)
       end
   end

   def nodeSetOffSoft
	allOffSoft
   end

   #
   # Function for Forcibly Switching off a node. This command is initiated 
   # by the user. If the node is registered, then the CMC sends the command 
   # to the CM and updates the node status to NODE_POWERED_DOWN_PENDING. On 
   # subsequent  successful receipt of a status message from the node, the 
   # status is updated to NODE_POWERED_DOWN depending on the parameters of 
   # the cmStatus field. If the node is not registered, then an exception is 
   # raised.  A delay of 0.001 seconds to avoid the current surge. On succes, 
   # the node LED is turned OFF and an ACK will come back to the CMC. This 
   # commands initiates a forcible shutdown.
   #
   def offHard
       if (@nodeActiveInactive == NODE_INACTIVE)
         raise "Node Not Active, No Operation Allowed"
       end
       if ( readCondition == NODE_NOT_REGISTERED )
       	   warn("Command Processing Error, Node Not Registered")
           raise "Node Not Registered for Testbed"
       elsif ( readCondition == NODE_POWERED_UP )
	   updateCondition(NODE_POWERED_DOWN_PENDING)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_POWER_DOWN_HARD, @nodeType)
	   sleep(0.01)
       end
   end

   #
   # Function for forcibly switching off all the nodes.  Only the nodes that have been 
   # registered will be switched off. The  unregistered nodes will be ignored. Same as 
   # the previous function in other respects.  On success, LEDs of the nodes will be 
   # turned OFF and ACKs will come back to the CMC.
   #
   def allOffHard
       if (@nodeActiveInactive == NODE_INACTIVE)
         return
       end
       if ( readCondition == NODE_NOT_REGISTERED )
            return
       elsif ( readCondition == NODE_POWERED_UP )
	   updateCondition(NODE_POWERED_DOWN_PENDING)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_POWER_DOWN_HARD, @nodeType)
	   sleep(0.01)
       end
   end

   def nodeSetOffHard
	allOffHard
   end

   # 
   # Function to Reset a node. This command is initiated by the user. If the 
   # node is registered, then the CMC sends the command to the CM and updates 
   # the node status to NODE_RESET. If the node is not registered, then an 
   # exception is raised. On success, an ACK will come back to the CMC. 
   #
   def reset
       if (@nodeActiveInactive == NODE_INACTIVE)
         raise "Node Not Active, No Operation Allowed"
       end
       if ( readCondition == NODE_NOT_REGISTERED )
       	   warn("Command Processing Error, Node Not Registered")
           raise "Node Not Registered for Testbed"
       else
	   updateCondition(NODE_RESET)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_RESET, @nodeType)
       end
   end

   #
   # Function to reset all the nodes.  Only the nodes that have been 
   # registered will be reset. The  unregistered nodes will be ignored. Same as 
   # the previous function in other respects. On success, ACKs will come back 
   # to the CMC.
   #
   def allReset
       if (@nodeActiveInactive == NODE_INACTIVE)
         return
       end
       if ( readCondition == NODE_NOT_REGISTERED )
	   return
       else
	   updateCondition(NODE_RESET)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_RESET, @nodeType)
       end
   end

   def nodeSetReset
	allReset
   end


   #
   # Function to automatically enable Web updates.  Only the nodes that have been 
   # registered will be reset. For an unregistered node, an exception will be raised.  
   # On success an ACK will come back to the CMC and in the telnet session, the "Auto
   # Web Enabled" field will be set to Yes.
   #
   def updateEnable
       if (@nodeActiveInactive == NODE_INACTIVE)
         raise "Node Not Active, No Operation Allowed"
       end
       if ( readCondition == NODE_NOT_REGISTERED )
       	   warn("Command Processing Error, Node Not Registered")
           raise "Node Not Registered for Testbed"
       else
	   updateCondition(NODE_ENABLE)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_UPDATE_ENABLE, @nodeType)
       end
   end

   def nodeSetUpdateEnable
       if (@nodeActiveInactive == NODE_INACTIVE)
         return
       end
       if ( readCondition == NODE_NOT_REGISTERED )
	   return
       else
	   updateCondition(NODE_ENABLE)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_UPDATE_ENABLE, @nodeType)
       end
   end

   #
   # Function to automatically disable Web updates.  Only the nodes that have been 
   # registered will be reset. For an unregistered node, an exception will be raised.  
   # On success an ACK will come back to the CMC and in the telnet session, the "Auto
   # Web Enabled" field will be set to No.
   #
   def updateDisable
       if (@nodeActiveInactive == NODE_INACTIVE)
         raise "Node Not Active, No Operation Allowed"
       end
       if ( readCondition == NODE_NOT_REGISTERED )
       	   warn("Command Processing Error, Node Not Registered")
           raise "Node Not Registered for Testbed"
       else
	   updateCondition(NODE_DISABLE)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_UPDATE_DISABLE, @nodeType)
       end
   end

   def nodeSetUpdateDisable
       if (@nodeActiveInactive == NODE_INACTIVE)
         return
       end
       if ( readCondition == NODE_NOT_REGISTERED )
	   return
       else
	   updateCondition(NODE_DISABLE)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_UPDATE_DISABLE, @nodeType)
       end
   end


   #
   # Function to remotely identify a CM from the CMC.  Only the nodes that have been 
   # registered will be identified. For an unregistered node, an exception will be raised.  
   # On success an ACK will come back to the CMC and the local highly visible LED on the 
   # CM will blink twice/second for approximately a 20 second period (the node needs to be 
   # powered up previously).
   #
   def identify
       if (@nodeActiveInactive == NODE_INACTIVE)
         raise "Node Not Active, No Operation Allowed"
       end
       if ( readCondition == NODE_NOT_REGISTERED )
       	   warn("Command Processing Error, Node Not Registered")
           raise "Node Not Registered for Testbed"
       else
	   updateCondition(NODE_IDENTIFY)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_IDENTIFY_NODE, @nodeType)
       end
   end

   #
   # Function to remotely identify all CMs from the CMC.  Only the nodes that have been 
   # registered will be identified. An unregistered node will be ignored .  
   # On success an ACK will come back to the CMC and the local highly visible LED on the 
   # CM will blink twice/second for approximately a 20 second period (the node needs to be 
   # powered up previously).
   #
   def allIdentify
       if (@nodeActiveInactive == NODE_INACTIVE)
         return
       end
       if ( readCondition == NODE_NOT_REGISTERED )
	   return
       else
	   updateCondition(NODE_IDENTIFY)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_IDENTIFY_NODE, @nodeType)
       end
   end

   def nodeSetIdentify
       allIdentify
   end

   #
   # Function to initiate inventory check.  When the CMC sends down this command, a 
   # single command on the node console is executed to look at the entire inventory. 
   # Only the nodes that have been registered will be checked. For an unregistered node, 
   # an exception will be raised. On success an ACK will come back to the CMC. 
   #
   def hostEnroll
       if (@nodeActiveInactive == NODE_INACTIVE)
         raise "Node Not Active, No Operation Allowed"
       end
       if ( readCondition == NODE_NOT_REGISTERED )
       	   warn("Command Processing Error, Node Not Registered")
           raise "Node Not Registered for Testbed"
       else
	   updateCondition(NODE_HOST_ENROLL)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_HOST_ENROLL, @nodeType)
       end
   end

   #
   # Function to initiate inventory check for all nodes.  When the CMC sends down this 
   # command, a single command on the node console is executed to look at the entire inventory. 
   # Only the nodes that have been registered will be checked. On success an ACK will come 
   # back to the CMC. 
   #
   def allHostEnroll
       if (@nodeActiveInactive == NODE_INACTIVE)
         return
       end
       if ( readCondition == NODE_NOT_REGISTERED )
	   return
       else
	   updateCondition(NODE_HOST_ENROLL)
           @communicator.constructSendCmd(@myPort, @ipaddr, CM_CMD_HOST_ENROLL, @nodeType)
       end
   end

   def nodeSetHostEnroll
       allHostEnroll
   end

   #
   #
   #
   def nodeStatus
      f3v = (@status[0].to_f) * @f3vconv
      f5v = (@status[1].to_f) * @f5vconv
      f12v = (@status[2].to_f) * @f12vconv
      temperature = ((9.0 * @status[3].to_f)/5.0) + 32.5

      time = readUpdtStatusTime(READ_STATUS)
      ttime = (Time.now).to_i - time.to_i
      if ( (CM_STATUS_MSG_ARR_TIME - ttime) >= 0)
         str = (CM_STATUS_MSG_ARR_TIME - ttime).to_s
      else
         str = "0"
      end
      nstatus = "  <TimeOutLeft>#{str}</TimeOutLeft>\n"
      str = (@ipaddr).to_s
      nstatus += "  <ipAddr>#{str}</ipAddr>\n"
      str = (@myPort).to_s
      nstatus += "  <port>#{str}</port>\n"
      str = (CMC_SOFTWARE_VERSION).to_s
      nstatus += "  <cmVersion>#{str}</cmVersion>\n"

      nstatus += "  <voltage33>#{f3v} V</voltage33>\n"
      nstatus += "  <voltage50>#{f5v} V</voltage50>\n"
      nstatus += "  <voltage120>#{f12v} V</voltage120>\n"
      nstatus += "  <temperature>#{temperature.to_i} F</temperature>\n"

      nstatus += "  <MAC0>" + @mac0 + "</MAC0>\n"
      nstatus += "  <MAC1>" + @mac1 + "</MAC1>\n"
      nstatus += "  <MAC2>" + @mac2 + "</MAC2>\n"
      nstatus += "  <MAC3>" + @mac3 + "</MAC3>\n"

      return nstatus
   end

   def getStatusComponent
      f3v = (@status[0].to_f) * @f3vconv
      f5v = (@status[1].to_f) * @f5vconv
      f12v = (@status[2].to_f) * @f12vconv
      temperature = ((9.0 * @status[3].to_f)/5.0) + 32.5

      str = "voltage33='#{f3v}'"
      str +=" voltage50='#{f5v}'"
      str +=" voltage120='#{f12v}'"
      str +=" Temperature='#{temperature.to_i} F'"

      return str
   end

   def setNodeInactive
        @nodeActiveInactive = NODE_INACTIVE
   end

   def setNodeActive
        @nodeActiveInactive = NODE_ACTIVE
   end

   def setNodeUnregistered
       updateCondition(NODE_NOT_REGISTERED)
   end

 end
end
# module CMC
