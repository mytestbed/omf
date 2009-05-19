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
# This file implements the Communicator class, the Message Pool class,
# and the Message Packet class. The Communicator class handles all the 
# low-level communication betweent the CMs and the CMC. Each Communicator 
# has its own message pool which is implemented by the Message Pool class.
# The Message Pool class stores all messages for which no ACK has been 
# received. The Message Packet class handles all operations on a CM-CMC 
# message packet. The CM-CMC message packet has the following fields:
# 	seqId    : 4 bytes, sequence no. of the message being sent
#	timetag  : 4 bytes, message timestamp 
#	pktFormat: 2 bytes, format handled is 2
#	cmd	 : 2 bytes, cmd sent/received to/from CM 
#	myIp	 : 4 bytes, IP address of the CM that sent the message
#	version  : 2 bytes, software version
#	nodeType : 2 bytes, grid node, support node, sandbox node
#	cmStatus : 4 bytes, 3.3v, 5v, 12v, temperature
#	mac0	 : 6 bytes, MAC address
#	mac1	 : 6 bytes, MAC address
#	mac2	 : 6 bytes, MAC address
#	mac3	 : 6 bytes, MAC address
#       
require 'socket'
require 'monitor'
require 'omf-common/mobject'

module CMC

    # Message Pool Operations
    ADD_MESSAGE    = 1
    DELETE_MESSAGE = 2
    CHECK_MESSAGE  = 3
  
    # Commands from CM to CMC and replies from CMC to CM
    CM_CMD_REGISTER_CM               = 0x01
    CM_CMD_REGISTER_CM_REPLY         = 0x81
    CM_CMD_STATUS_CM	             = 0x02
    CM_CMD_STATUS_CM_REPLY           = 0x82
    CM_CMD_IDENTIFY_REQUEST_CM	     = 0x07
    CM_CMD_IDENTIFY_REQUEST_CM_REPLY = 0x87

    # Constants to construct the CMC-CM message packet
    CMC_SOFTWARE_VERSION = 0x000c
    CM_PORT              = 1234
    CM_CMC_MSG_SIZE      = 48
    CM_PACKET_FORMAT     = 2
    CM_MYIP		 = 100120001
    CM_CMSTATUS		 = "0000"
    CM_MAC		 = "000000"

    # Constant for roughly the decimal value of 1 v
    CM_V_ON_THRESHOLD    = 39

    # Constant to define the time of wait for an ACK
    CM_ACK_TIMEOUT		   = 600

    # Constant for the sleep duration of the TIMEOUT Thread
    # Used for thread synchronization
    CM_SLEEP_INTERVAL              = 1

    # Constant for Chassis Manager IP address and Port used to open the socket to 
    # send / receive messages to / from the CM

    CHASSIS_MANAGER_ADDR             = "10.1.200.1"    # Hard-coded CMC IP Address

  #
  # This class handles all the low-level communication
  # Each testbed has it's own communicator.
  #
  class  Communicator < ::MObject

    #
    # Create a communicator from the parameters in the config hash
    #
    def Communicator.create(name, config)
      ip = config['ip']
      port = config['port']
      if ! (ip && port)
	raise "Missing arguments. Require 'ip', and 'port'"
      end
      Communicator.new(name, ip, port)
    end

    #
    # Return the communicator described in 'config' hash.
    # If 'config' is nil, return the 'default' communicator.
    #
    def Communicator.find(config)
      if (config == nil)
	#return default
	return @@name2comm['default']
      end

      ip = config['ip']
      port = config['port']
      if !(ip && port)
	raise "Missing arguments. Require 'ip', and 'port'"
      end
      @@ipPort2comm["#{ip}:#{port}"]
    end

    @@name2comm = Hash.new
    @@ipPort2comm = Hash.new

    # 
    # Initialize the Communicator
    #
    def initialize(name, recvHost, recvPort)

      debug("Initializing Communicator")
      @MsgpoolObj = MessagePool.new(self)

      # Open socket to listen at the IP address of "10.1.200.1" and port# 9030
      # Parse message received from CM
      # Retrieve CM IP and port#

      @cmc_socket = UDPSocket.open
      begin
	@cmc_socket.bind(recvHost, recvPort)
      rescue Exception => ex
	error("Can't bind to #{recvHost}:#{recvPort}\n\t#{ex}")
      end


      # thread to process commands from CM to CMC
      Thread.new {
	while (@cmc_socket != nil)
	  begin
            #debug("*************************  PROCESS MESSAGE THREAD ******************")
	    msg = @cmc_socket.recvfrom(48)
	    processMessage(msg)
	  rescue Exception => ex
	    bt = ex.backtrace.join("\n\t")
	    error("CMC", "Exception: #{ex} (#{ex.class})\n\t#{bt} at recvfrom")
	  end
	end
      }
      @@name2comm[name] = self
      @@ipPort2comm["#{recvHost}:#{recvPort}"] = self
    end

    #
    # Sends command to CM
    #
    def sendCommand(cmprt, cmadr, cm_msg)
      cmstr = cm_msg
      @cmc_socket.send(cmstr, 0, cmadr, cmprt)
    end

    #
    # Construct a CMC-CM msg packet and send it to CM
    #
    def constructSendCmd(ipport, ipaddr, cmd, nodeType)
       nmsg = MsgPacket.new
       cmstr = nmsg.constructMsg(cmd, nodeType)
       sendCommand(ipport, ipaddr, cmstr)
       insertPool(cmstr, ipaddr)
    end

    # Private from here on out
    private

    #
    # Process a UDP message from a CM. 'udp_msg[0]' contains the
    # actual message, while 'udp_msg[1]' contains the IP address
    # of the sender.
    #
    def processMessage(udp_msg)

      nmsg = MsgPacket.new

      cm_port = udp_msg[1][1]
      cm_addr = udp_msg[1][2]
      cm_msg = udp_msg[0]

      nmsg.demarshallMsg(udp_msg[0], cm_addr)	
      nstatus = nmsg.cmStatus
      sys_3v = nmsg.cmStatus[0].to_i
      sys_5v = nmsg.cmStatus[1].to_i
      sys_12v = nmsg.cmStatus[2].to_i

      mac0 = nmsg.to_hex_s(nmsg.mac11[0].to_i)
      mac1 = nmsg.to_hex_s(nmsg.mac11[1].to_i)
      mac2 = nmsg.to_hex_s(nmsg.mac11[2].to_i)
      mac3 = nmsg.to_hex_s(nmsg.mac11[3].to_i)
      mac4 = nmsg.to_hex_s(nmsg.mac11[4].to_i)
      mac5 = nmsg.to_hex_s(nmsg.mac11[5].to_i)
      mac1str = "#{mac0}:#{mac1}:#{mac2}:#{mac3}:#{mac4}:#{mac5}"

      mac0 = nmsg.to_hex_s(nmsg.mac12[0].to_i)
      mac1 = nmsg.to_hex_s(nmsg.mac12[1].to_i)
      mac2 = nmsg.to_hex_s(nmsg.mac12[2].to_i)
      mac3 = nmsg.to_hex_s(nmsg.mac12[3].to_i)
      mac4 = nmsg.to_hex_s(nmsg.mac12[4].to_i)
      mac5 = nmsg.to_hex_s(nmsg.mac12[5].to_i)
      mac2str = "#{mac0}:#{mac1}:#{mac2}:#{mac3}:#{mac4}:#{mac5}"

      mac0 = nmsg.to_hex_s(nmsg.mac13[0].to_i)
      mac1 = nmsg.to_hex_s(nmsg.mac13[1].to_i)
      mac2 = nmsg.to_hex_s(nmsg.mac13[2].to_i)
      mac3 = nmsg.to_hex_s(nmsg.mac13[3].to_i)
      mac4 = nmsg.to_hex_s(nmsg.mac13[4].to_i)
      mac5 = nmsg.to_hex_s(nmsg.mac13[5].to_i)
      mac3str = "#{mac0}:#{mac1}:#{mac2}:#{mac3}:#{mac4}:#{mac5}"

      mac0 = nmsg.to_hex_s(nmsg.mac14[0].to_i)
      mac1 = nmsg.to_hex_s(nmsg.mac14[1].to_i)
      mac2 = nmsg.to_hex_s(nmsg.mac14[2].to_i)
      mac3 = nmsg.to_hex_s(nmsg.mac14[3].to_i)
      mac4 = nmsg.to_hex_s(nmsg.mac14[4].to_i)
      mac5 = nmsg.to_hex_s(nmsg.mac14[5].to_i)
      mac4str = "#{mac0}:#{mac1}:#{mac2}:#{mac3}:#{mac4}:#{mac5}"

      if ( nmsg.pktFormat != CM_PACKET_FORMAT)
	warn("Packet With UnKnown Format ", nmsg.pktFormat, " Not Processed")
      else 

        nnode = CmcNode.fromIP(cm_addr)
	if (nnode == nil)
	  debug(" Invalid IP address = ", cm_addr)
	  return
	end

	case (nmsg.cmd)

	when CM_CMD_REGISTER_CM
	  # CM calls in first time
	  #debug(" *** Received REGISTER_CM Message **************")
	  nmsg.updateCmd(CM_CMD_REGISTER_CM_REPLY)
	  cmstr = nmsg.marshallMsg
	  condition = NODE_REGISTERED
	  nnode.updateStatus(nmsg.myIp, cm_port, nmsg.version, cm_addr,
	  		     nmsg.nodeType, condition, 
			     nmsg.cmStatus, mac1str, mac2str, mac3str, mac4str)
          sendCommand(cm_port, cm_addr, cmstr)

	when CM_CMD_STATUS_CM
	  # Periodic status report
	  #debug(" *** Received STATUS_CM Message **************")
          condition = nnode.readCondition
          if (condition == NODE_NOT_REGISTERED )
             return
          end
	  if (nnode.nodeActiveInactive == NODE_INACTIVE)
	     return
	  end
	  nmsg.updateCmd(CM_CMD_STATUS_CM_REPLY)
          stime = nnode.readUpdtStatusTime(UPDATE_STATUS)
	  cmstr = nmsg.marshallMsg
          if ( ((sys_3v > CM_V_ON_THRESHOLD) || (sys_5v > CM_V_ON_THRESHOLD)))
	        condition = NODE_POWERED_UP
	  end

          if ( ((sys_3v < CM_V_ON_THRESHOLD) && (sys_5v < CM_V_ON_THRESHOLD)) )
	        condition = NODE_POWERED_DOWN
	  end
	  nnode.updateStatus(nmsg.myIp, cm_port, nmsg.version, cm_addr,
	  		     nmsg.nodeType, condition, 
			     nmsg.cmStatus, mac1str, mac2str, mac3str, mac4str)
	  sendCommand(cm_port, cm_addr, cmstr)
	  
	when CM_CMD_IDENTIFY_REQUEST_CM
	  # Called when CM's identity button was pressed
	  #debug(" *** Received IDENTIFY_CM Message **************")
	  nmsg.updateCmd(CM_CMD_IDENTIFY_REQUEST_CM_REPLY)
	  cmstr = nmsg.marshallMsg
	  condition = NODE_IDENTIFY_REQUEST
	  nnode.updateCondition(condition)
	  sendCommand(cm_port, cm_addr, cmstr)

	when CM_CMD_POWER_UP_REPLY
	  #debug(" *** Received POWER_UP_REPLY Message **************")
          nmsg.updateCmd(CM_CMD_POWER_UP)
          cmstr = nmsg.marshallMsg
	  removePool(cmstr, cm_addr)

	when CM_CMD_RESET_REPLY
	  #debug(" *** Received RESET_REPLY Message **************")
          nmsg.updateCmd(CM_CMD_RESET)
          cmstr = nmsg.marshallMsg
	  removePool(cmstr, cm_addr)

	when CM_CMD_POWER_DOWN_SOFT_REPLY
	  #debug(" *** Received POWER_DOWN_SOFT_REPLY Message **************")
          nmsg.updateCmd(CM_CMD_POWER_DOWN_SOFT)
          cmstr = nmsg.marshallMsg
	  removePool(cmstr, cm_addr)

	when CM_CMD_POWER_DOWN_HARD_REPLY
	  #debug(" *** Received POWER_DOWN_HARD_REPLY Message **************")
          nmsg.updateCmd(CM_CMD_POWER_DOWN_HARD)
          cmstr = nmsg.marshallMsg
	  removePool(cmstr, cm_addr)

	when CM_CMD_HOST_ENROLL_REPLY
	  #debug(" *** Received HOST_ENROLL_REPLY Message **************")
          nmsg.updateCmd(CM_CMD_HOST_ENROLL)
          cmstr = nmsg.marshallMsg
	  removePool(cmstr, cm_addr)

	when CM_CMD_IDENTIFY_NODE_REPLY
	  #debug(" *** Received IDENTIFY_NODE_REPLY Message **************")
          nmsg.updateCmd(CM_CMD_IDENTIFY_NODE)
          cmstr = nmsg.marshallMsg
	  removePool(cmstr, cm_addr)

	when CM_CMD_UPDATE_ENABLE_REPLY
	  #debug(" *** Received UPDATE_ENABLE_REPLY Message **************")
          nmsg.updateCmd(CM_CMD_UPDATE_ENABLE)
          cmstr = nmsg.marshallMsg
	  removePool(cmstr, cm_addr)

	when CM_CMD_UPDATE_DISABLE_REPLY
	  #debug(" *** Received UPDATE_DISABLE_REPLY Message **************")
          nmsg.updateCmd(CM_CMD_UPDATE_DISABLE)
          cmstr = nmsg.marshallMsg
	  removePool(cmstr, cm_addr)

	end
      end	
    end

    #
    # Call Message Pool to insert a message
    #
    def insertPool(msgstr, ipaddr)
      nmsg = MsgPacket::new
      nmsg.demarshallMsg(msgstr, ipaddr)
      @MsgpoolObj.operateMsgPool(ADD_MESSAGE, nmsg)
    end

    #
    # Call Message Pool to delete a message
    #
    def removePool(msgstr, ipaddr)
      nmsg = MsgPacket::new
      nmsg.demarshallMsg(msgstr, ipaddr)
      nmsg.updatetime(nmsg)
      @MsgpoolObj.operateMsgPool(DELETE_MESSAGE, nmsg)
    end


    # Message Pool to hold messages for which ACK needs to be sent.
    # This message pool is periodically checked to see if an ACK has been
    # received. If not within the TIMEOUT limit, then the message is resent.
    class MessagePool < ::MObject

      #
      # Initialize the MessagePool
      #
      def initialize(communicator)
	@communicator = communicator
	@msgPool = Array.new
        @lock = Monitor.new

	Thread.new { 
	  while true
	    sleep(CM_SLEEP_INTERVAL)
	    #debug("------- TIMEOUT CHECK THREAD --------")
	    # FIXME: protect function with 'rescue'
	    begin
	      checkTimeout
	    rescue Exception => ex
	      bt = ex.backtrace.join("\n\t")
	      error("Exception: #{ex} (#{ex.class})\n\t#{bt} at timeout")
	    end
	  end
	}
      end

      #
      # This is a common interface for Message Pool 
      # operations. The purpose of this common 
      # interface is thread synchronization
      #
      def operateMsgPool(operation, msg)
         @lock.synchronize { 
            timeoutMsgs = Array.new
            if (operation == ADD_MESSAGE)
	       insertPool(msg)
	    elsif (operation == DELETE_MESSAGE)
	       removePool(msg)
	    elsif (operation == CHECK_MESSAGE)
	       timeoutMsgs = checkPool(msg)
	    else
	       warn("Invalid Message Pool Operation")
	    end
	    return timeoutMsgs
	 }
      end

      #
      # Insert a message into the Pool with it's Timestamp(timetag field)
      #
      def insertPool(msg)
	@msgPool.insert(-1, msg)	
        len = @msgPool.length
	##debug("The Message Pool Length = ", len)
      end

      #  
      # Check for existence of prior messages from a CM and delete the messages.
      # 
      def removePool(msg)
	i = 0
        found = false
        while( i < @msgPool.length )
            pmsg = MsgPacket.new
            pmsg = @msgPool[i]
            if ( (pmsg.ipaddr == msg.ipaddr) && 
                 (pmsg.cmd == msg.cmd) && (pmsg.gettimetag <= msg.gettimetag) )
               found = true
               break
            end
            i = i + 1
        end 
	if ((found == true) && (i < @msgPool.length))
	  @msgPool.delete_at(i)
	  @msgPool.compact!
	end
      end


      #
      # Check the message pool for status  for messages that have not 
      # received an ACK for CM_ACK_TIMEOUT time. If such a message 
      # exists, then delete the message from the Message Pool.
      # Return an array of such messages.
      # 
      def checkPool(tmsg)
	timeoutMsgs = Array.new
	ret = tmsg.to_i
	i = 0
	index = 0
	while (i < (@msgPool.length))
	  if ( (ret - (@msgPool[i].gettimetag)) > CM_ACK_TIMEOUT )
            #debug("the current time = ", ret)
	    #debug("the message pool time = ", @msgPool[i].gettimetag)
	    timeoutMsgs[index] = @msgPool.at(i)
	    @msgPool.delete_at(i)
	    @msgPool.compact!
	    index = index + 1
	  end
	  i = i + 1
	end
        return timeoutMsgs 
      end

      private

      #
      # This checks the message pool for MESSAGE-ACK timeout.  
      # If there are any, then resend message
      #
      def checkTimeout
	t = Time.now
	ret = t.to_i
	timeoutMsgs = operateMsgPool(CHECK_MESSAGE, ret.to_s)
	i = 0
	while (i < timeoutMsgs.length)
	    cm_cmc_msg = timeoutMsgs.at(i) 
	    cmstr = cm_cmc_msg.marshallMsg
	    @communicator.sendCommand(CM_PORT, cm_cmc_msg.ipaddr, cmstr)
	    i = i + 1
	end
      end

    end
    # end of class MessagePool

  end
  # end of class Communicator

  #
  # This class handles all operations on the CM-CMC message packet
  #
  class MsgPacket < ::MObject

    attr_reader :ipaddr
    attr_reader :seqId
    attr_reader :timetag
    attr_reader :pktFormat
    attr_reader :cmd
    attr_reader :myIp
    attr_reader :version
    attr_reader :nodeType
    attr_reader :cmStatus
    attr_reader :mac11
    attr_reader :mac12
    attr_reader :mac13
    attr_reader :mac14

    @@cmdSeqNo = 0

    # initialize a new string of size 48 bytes
    def initialize
	@mac11 = Array.new
	@mac12 = Array.new
	@mac13 = Array.new
	@mac14 = Array.new

        @istr = String.new
	i = 0
        while ( i < CM_CMC_MSG_SIZE )
          @istr = @istr + ' '
          i = i + 1
        end
    end

    # Conversion of "timetag" to its corresponding 4 byte string
    # number = (n1) * 256 + (n2) * (256^2) + (n3) * (256^3) + (n4) * (256^4)
    # 4-byte string = "\n1\n2\n3\n4" with 0s padded as necessary e.g. "\00n1"
    def to_s_i(num)

      timestr = String.new("0000")
      rem1 = 0
      rem2 = 0
      rem3 = 0
      rem4 = 0

      range0 = 1
      range1 = range0 * 256
      range2 = range1 * 256
      range3 = range2 * 256
      range4 = range3 * 256

      timestr[0] = 0
      timestr[1] = 0
      timestr[2] = 0
      timestr[3] = 0

      fibyte = 0
      twbyte = 0
      thbyte = 0
      frbyte = 0

      if (num >= range3 )
	   temp = num / range3
	   frbyte = temp.truncate
	   rem1 = num % range3
      end

      if (num >= range2)
	   temp = rem1 / range2
	   thbyte = temp.truncate
	   rem2 = rem1 % range2
      end

      if (num >= range1)
	   temp = rem2 / range1
	   twbyte = temp.truncate
	   rem3 = rem2 % range1
      end

      fibyte = rem3
      
      timestr[0] = fibyte 
      timestr[1] = twbyte 
      timestr[2] = thbyte 
      timestr[3] = frbyte

      return timestr
    end

    #
    # Conversion for MAC addresses in status
    #
    def to_hex_s(num)

      mac = String.new("00")
      mac[0] = '0'
      mac[1] = '0'
      rem = 0
      range = 16
      fbyte = 0

      temp = num / range
      fbyte = temp.truncate
      if (fbyte < 10)
         mac[0] = fbyte.to_s
      elsif( fbyte == 10)
         mac[0] = 'A'
      elsif( fbyte == 11)
         mac[0] = 'B'
      elsif( fbyte == 12)
         mac[0] = 'C'
      elsif( fbyte == 13)
         mac[0] = 'D'
      elsif( fbyte == 14)
         mac[0] = 'E'
      elsif( fbyte == 15)
         mac[0] = 'F'
      end

      rem = num % range
      if (rem < 10)
         mac[1] = rem.to_s
      elsif( rem == 10)
         mac[1] = 'A'
      elsif( rem == 11)
         mac[1] = 'B'
      elsif( rem == 12)
         mac[1] = 'C'
      elsif( rem == 13)
         mac[1] = 'D'
      elsif( rem == 14)
         mac[1] = 'E'
      elsif( rem == 15)
         mac[1] = 'F'
      end
     
      return mac
    end

    # Conversion of a 4-byte string to number
    # 4-byte string = "\n1\n2\n3\n4" with 0s padded as necessary
    # number = n1 * (256) + n2 * (256^2) + n3 * (256^3) + n4 * (256^4)
    def to_i(str)
      i = 0
      b = 1
      str.each_byte { |c| i += b*c; b *= 256 }
      return i
    end

    # update the command field
    def updateCmd(cmd)
         @cmd = cmd
    end

    def updatetime(nmsg)
       t = Time.now
       timestr = to_s_i(t.to_i)
       @timetag[0] = timestr[0]
       @timetag[1] = timestr[1]
       @timetag[2] = timestr[2]
       @timetag[3] = timestr[3]
    end

    # Return the timetag as a number
    def gettimetag
       ttag = to_i(@timetag)
       return ttag
    end

    #
    # Parses the message that is exchanged between CM and CMC
    # and separates the different message contents as per the
    # sizes of the fields in the CM-CMC message packet.
    #
    def demarshallMsg(cmsg, addr)

      @ipaddr = addr			     # IPAddress
      @seqId = to_i(cmsg.slice(0..3))	     # seqId
      @timetag = cmsg.slice(4..7)	     # timetag
      @pktFormat = to_i(cmsg.slice(8..9))    # pktFormat
      @cmd = to_i(cmsg.slice(10..11))	     # cmd
      @myIp = to_i(cmsg.slice(12..15))	     # myIp
      @version = cmsg.slice(16..17)	     # version	
      @nodeType = to_i(cmsg.slice(18..19))   # nodeType
      @cmStatus = (cmsg.slice(20..23))       # status	
      @mac11[0] = (cmsg.slice(24))   # mac11
      @mac11[1] = (cmsg.slice(25))   # mac11
      @mac11[2] = (cmsg.slice(26))   # mac11
      @mac11[3] = (cmsg.slice(27))   # mac11
      @mac11[4] = (cmsg.slice(28))   # mac11
      @mac11[5] = (cmsg.slice(29))   # mac11

      @mac12[0] = (cmsg.slice(30))   # mac12
      @mac12[1] = (cmsg.slice(31))   # mac12
      @mac12[2] = (cmsg.slice(32))   # mac12
      @mac12[3] = (cmsg.slice(33))   # mac12
      @mac12[4] = (cmsg.slice(34))   # mac12
      @mac12[5] = (cmsg.slice(35))   # mac12

      @mac13[0] = (cmsg.slice(36))   # mac12
      @mac13[1] = (cmsg.slice(37))   # mac12
      @mac13[2] = (cmsg.slice(38))   # mac12
      @mac13[3] = (cmsg.slice(39))   # mac12
      @mac13[4] = (cmsg.slice(40))   # mac12
      @mac13[5] = (cmsg.slice(41))   # mac12

      @mac14[0] = (cmsg.slice(42))   # mac12
      @mac14[1] = (cmsg.slice(43))   # mac12
      @mac14[2] = (cmsg.slice(44))   # mac12
      @mac14[3] = (cmsg.slice(45))   # mac12
      @mac14[4] = (cmsg.slice(46))   # mac12
      @mac14[5] = (cmsg.slice(47))   # mac12

    end

    #
    # Construct a CM-CMC message packet in those cases where the 
    # message has been received previously, and the message fields are 
    # stored in the instance variables when the message is demarshalled.
    # The instance variables are used to construct the message.
    # Returns a string.
    #
    def marshallMsg
       msgstr = String.new(@istr) 
       @@cmdSeqNo = @@cmdSeqNo + 1
       seqstr = to_s_i(@@cmdSeqNo)
       msgstr[0] = seqstr[0]
       msgstr[1] = seqstr[1]
       msgstr[2] = seqstr[2]
       msgstr[3] = seqstr[3]
       t = Time.now
       timestr = to_s_i(t.to_i)
       msgstr = msgstr + timestr 
       msgstr[8] = @pktFormat
       msgstr[9] = 0
       msgstr[10] = @cmd
       msgstr[11] = 0
       ipstr = to_s_i(@myIp)
       msgstr = msgstr + ipstr 
       msgstr = msgstr + @version
       msgstr[18] = @nodeType
       msgstr[19] = 0
       msgstr = msgstr + @cmStatus.to_s
       msgstr = msgstr + @mac11.to_s 
       msgstr = msgstr + @mac12.to_s
       msgstr = msgstr + @mac13.to_s 
       msgstr = msgstr + @mac14.to_s

       return msgstr
    end

    #
    # Constructs a totally new CM-CMC message. This function is used for those cases
    # where the CMC sends a command to the CM. This function returns a 48 byte string
    # The message fields are constructed using pre-defined constants.
    # Returns a string.
    #
    def constructMsg(cmd, nodeType)
       msgstr = String.new(@istr)
       @@cmdSeqNo = @@cmdSeqNo + 1
       seqstr = to_s_i(@@cmdSeqNo)
       msgstr[0] = seqstr[0]
       msgstr[1] = seqstr[1]
       msgstr[2] = seqstr[2]
       msgstr[3] = seqstr[3]
       t = Time.now
       timestr = to_s_i(t.to_i)
       msgstr[4] = timestr[0]
       msgstr[5] = timestr[1]
       msgstr[6] = timestr[2]
       msgstr[7] = timestr[3]
       msgstr[8] = CM_PACKET_FORMAT 
       msgstr[9] = 0
       if (cmd == CM_CMD_IDENTIFY_NODE)
          msgstr[10] = CM_CMD_IDENTIFY_NODE
          msgstr[11] = 0
       else
          msgstr[10] = cmd
          msgstr[11] = 0
       end
       ipstr = to_s_i(CM_MYIP)
       msgstr = msgstr + ipstr 
       msgstr = msgstr + (CMC_SOFTWARE_VERSION).to_s
       msgstr[18] = nodeType
       msgstr[19] = 0
       msgstr = msgstr + CM_CMSTATUS
       msgstr = msgstr + CM_MAC
       msgstr = msgstr + CM_MAC
       msgstr = msgstr + CM_MAC
       msgstr = msgstr + CM_MAC
 
       return msgstr            
    end
  end
  # end of class MsgPacket

end
# module CMC
