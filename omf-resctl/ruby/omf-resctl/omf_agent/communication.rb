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
# = communication.rb
#
# == Description
#
# This file defines the Communicator class and its sub-class TcpServerCommunicator,
# TcpCommunicator, and MCCommunicator.
# These classes implement the communication link between this NA and the NH
#
# We implement the following communication protocol with an emphasis on
# minimizing the need for an agent (many) to send to a handler (one).
# There is no need for agent to agent communication.
#
# We also assume that a handler is sending at least a message every N seconds
# allowing an agent to determine if it lost connection to its handler. A special
# command from the handler will solicit "heartbeat" replies from the targeted
# agents, allowing the handler to establish which agents are still listening
#
# From handler:
#
#   sequenceNo target command arg1 arg2 ...
#
# From agent:
#
#   senderId contextId command arg1 arg2 ...
#
#  This file will be phased out during the implementation of the pubsub agent
#
require 'thread'
require 'monitor'
require 'benchmark'
require 'omf-common/multicast2.rb'
require 'omf-common/mobject'
require 'omf-common/lineSerializer'
#require 'profiler'

#
# This class defines a general Communicator module for NA, its sub-class will define
# alternate specific communication schemes that can be used by the NA.
#
class Communicator < MObject

  # Singleton
  @@instance = nil
  @@localAddr = nil

  #
  # Return the unique instance of this Singleton
  #
  # [Return] the instance of this Communicator
  #
  def self.instance

    if (@@instance != nil)
      return @@instance
    end

    params = NodeAgent.instance.config('comm')
    if (params['server_port'] != nil)
      @@instance = TcpServerCommunicator.new(params)
    else
      handlerAddr = params['handler_addr']
      if multicastAddress?(handlerAddr)
        @@instance = MCCommunicator.new(params)
      else
        @@instance = TcpCommunicator.new(params)
      end
    end
    return @@instance
  end

  #
  # Test if an IP address is a Multicast one
  #
  # - addr = the address to test
  #
  # [Return] true if the address is a Multicast one, false otherwise
  #
  def self.multicastAddress?(addr)
    return (addr.match('224') != nil)
  end

  #
  # Return 'true' if this node agent is running on a linux platform
  #
  # [Return] true or false
  #
  def self.isPlatformLinux?
    return RUBY_PLATFORM.include?('linux')
  end

  # 
  # Return the x coordinate for this NA 
  # Raises an error message if the coordinate is not set/available
  #
  # [Return] x coordinate
  #
  def x
    if (@@x.nil?)
      raise "Cannot determine X coordinate"
    end
    return @@x
  end

  # 
  # Set the x coordinate for this NA 
  #
  # - x = value for the X coordinate
  #
  def setX(x)
    @@x = x
  end

  # 
  # Return the y coordinate for this NA 
  # Raises an error message if the coordinate is not set/available
  #
  # [Return] y coordinate
  #
  def y
    if (@@y.nil?)
      raise "Cannot determine X coordinate"
    end
    return @@y
  end

  # 
  # Set the y coordinate for this NA 
  #
  # - y = value for the Y coordinate
  #
  def setY(y)
    @@y = y
  end

  #
  # Return the IP address of the control interface
  #
  # This method assumes that the 'ifconfig' command returns something like:
  #
  # eth1      Link encap:Ethernet  HWaddr 00:0D:61:46:1E:E1
  #           inet addr:10.10.101.101  Bcast:10.10.255.255  Mask:255.255.0.0
  #           UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
  #           RX packets:118965 errors:0 dropped:0 overruns:0 frame:0
  #           TX packets:10291 errors:0 dropped:0 overruns:0 carrier:0
  #           collisions:0 txqueuelen:1000
  #           RX bytes:17394487 (16.5 MiB)  TX bytes:1073233 (1.0 MiB)
  #           Interrupt:11 Memory:eb024000-0
  #
  # [Return] an IP address
  #
  def localAddr()
    if @@localAddr != nil
      return @@localAddr
    end

    isConfigured = false
    while (isConfigured == false)
      if Communicator.isPlatformLinux?
        match = /[.\d]+\.[.\d]+\.[.\d]+\.[.\d]+/
        lines = IO.popen("/sbin/ifconfig #{@localIF}", "r").readlines
        if (lines.length >= 2)
          @@localAddr = lines[1][match]
        end
        # hack for APP1
        #if @@localAddr == nil
        #  @@localAddr = IO.popen("/sbin/ifconfig eth0", "r").readlines[1][match]
        #end
      else
        # WINDOWS HACK
        @@localAddr = "127.0.0.0"
      end

      if (@@localAddr.nil?)
        #raise "Cannot determine local IP address to listen on"
        debug "Cannot determine local IP address to listen on..."
        sleep(10)
      else 
        isConfigured = true;
      end
    end
    debug("Local control IP: #{@@localAddr}")

    # Once we have the local Control IP Addr, we can set the coordinate of this
    # node on the grid, following the convention: AAA.BBB.x.y
    match = /.*\.(\d+)\.(\d+)$/.match(@@localAddr)
    @@x = match[1].to_i
    @@y = match[2].to_i

    return @@localAddr
  end
 
  #
  # Reset this Communicator
  #
  def reset
    @handlerTimestamp = Time.now
    @inSeqNumber = -1
    @queue && @queue.clear
  end

  private

  #
  # Create a the single instance of this Communicator
  #
  # - params = not used at the moment
  #
  def initialize(params)
    reset

    @queue = Queue.new
    Thread.new() {
      while true do
        #Thread.current.priority = +2
        begin
          line = @queue.deq
          debug("Process message (rem:", @queue.length, "): '", line, "'")
          a = LineSerializer.to_a(line)
          t = Time.now
          processCommand(a)
          debug("Time taken to process command: ", Time.now - t)
          Thread.pass
        rescue Exception => err
          bt = err.backtrace.join("\n\t")
          error("While processing command '#{line}' Error: '#{err}'")
          debug("While processing command '#{line}' \n\tError: #{err}\n\t#{bt}")
        end
      end
    }
  end

  #
  # Send a 'WHO AM I' message to the NH
  #
  def sendWHOAMI
    addr, port = getListenAddress()
    send!(0, "WHOAMI", AgentCommands::PROTOCOL_VERSION,
              addr, port,
              NodeAgent::AGENT_VERSION, NodeAgent.instance.imageName)
  end

  #
  # Send a 'EXPERIMENT DONE' message to the NH
  #
  def sendEXPDONE
    debug "Sending END_EXPERIMENT to the NH"
    send!(0, "END_EXPERIMENT", "123 456")
  end

  #
  # Return the listening address of this Communicator
  #
  def getListenAddress()
    return ['-', -1]
    # NOTE: Legacy code, is something missing here?
  end

  #
  # Return a specific parameter from a list
  #
  # - params = the list of all parameters
  # - name = the name of the parameter to select and return
  # - mandatory = flag indicating if this parameter is a mandatory one (defaul 'true')
  # 
  # [Return] return the requested parameter from the list, raise an error if it 
  #          is declared as 'mandatory' but is not found in the list.
  #
  def getParam(params, name, mandatory = true)
    p = params[name]
    if (mandatory && p.nil?)
      raise "Missing '#{name}' parameter"
    end
    p
  end

  #
  # Listen on 'sock' for new commands. All received
  # commands are being put into the queue '@queue'
  #
  # - sock = the socket to listen on 
  #
  def listenOn(sock)
    @sock = sock
    Thread.new(sock) { |sock|
      begin
        while (@sock == sock) do
          Thread.current.priority = +1
          debug("Ready to receive commands")
          cmd = sock.recvfrom(1024)[0]
    if (cmd.length == 0)
      break
    end
          debug("Received #{cmd.length} bytes from socket")
          cmd.each {|line|
            debug('Pushed onto queue (l:', @queue.length, '): ', line)
            @queue.push(line)
          }
        end
      rescue EOFError
        # do nothing
      rescue Exception => err
        error("While listening for commands: #{err}")
      ensure
        @sock.close
        @sock = nil
        onHandlerDisconnected
      end
    }
  end

  #
  # Called when this Communicator lost contact with the NH after being enrolled to it.
  # Currently, when this happens, here we log it as debug message, and we reset the NA instance.
  #
  def onHandlerDisconnected()
    debug "Handler disconnected"
    NodeAgent.instance.reset
  end
end


#
# This sub-class TcpServerCommunicator defines a NA Communicator, 
# which will act as a TCP Server. In this design, the NH will act as a TCP
# client, connecting to the NA. 
#
class TcpServerCommunicator < Communicator

  #
  # Send a message
  #
  # - message = the text message to send
  #
  def send(*msgArray)
    send!(0, *msgArray)
  end

  #
  # If agent tunes into reliable multicast late, the handler
  # sends in its initial message the highest seq number already
  # used. This means any message with this seq# or any lower can be
  # ignored.
  #
  # - ignoreCnt = sequence number below which a message can be ignored
  #
  def ignoreUpTo(ignoreCnt)
    debug "Ignoring first #{ignoreCnt} commands"
    @inSeqNumber = ignoreCnt
  end

  #
  # Send a heartbeat back to the handler
  #
  def sendHeartbeat()
    send!(:HB, -1, -1, -1, -1)
    # Comment the following code:
    # TcpServerCommunicator only sends HB to acknowledge succesfully executed commands
    #if NodeAgent.instance.connected?
    #  send!(:HB, -1, -1, -1, -1)
    #else
    #  # haven't heard from nodeHandler yet, resend initial message
    #  sendWHOAMI
    #end
  end

  private

  #
  # Send a message
  #
  # - seqNo = sequence number of the message to send
  # - msgArray = the array of text to send
  #
  def send!(seqNo, *msgArray)
    message = "#{NodeAgent.instance.agentName} 0 #{LineSerializer.to_s(msgArray)}"
    debug("Send message: '#{message}'")
    @sock.write(message)
  end

  #
  # Initialize the sockets through which to send and receive messages
  #
  # - params = list of parameters used to initialize the socket ('server_port', 'local_if')
  #
  def initialize(params)

    super
    @params = params
    @listenPort = getParam(@params, 'server_port').to_i
    @localIF = getParam(@params, 'local_if')

    @serverSock = TCPServer.open(@listenPort)
    debug("Connected");

    Thread.new(@serverSock) { |ss|
      while ss == @serverSock do
        debug("Listen for handler call on '#{@listenPort}'")
        sock = ss.accept
        onHandlerConnected(sock)
      end
    }
  end

  #
  # Called when a NH connects to this NA
  #
  # - sock = socket used to communicate with the newly connected NH
  #
  def onHandlerConnected(sock)
    if (@sock != nil)
      # already listening to a handler
      sock.write('ERROR Already connected to a handler')
      sock.close
      return
    end
    listenOn(sock)
  end

  #
  # Process an incoming command from the NH. 
  # Commands should be of the form:
  #
  #   sequenceNo target command arg1 arg2 ...
  #
  # - argArray = array of received command line arguments
  #
  def processCommand(argArray)
    if argArray.size < 3
      raise "Command is too short '#{argArray.join(' ')}'"
    end

    seqNo = argArray.delete_at(0).to_i.abs
    if (seqNo > 0 && seqNo <= @inSeqNumber)
      # already got that one
      return
    end
    if (seqNo == 0 && NodeAgent.instance.connected? == true && argArray[1].upcase == "YOUARE")
      # already received a 'YOUARE'... to add more names use 'ALIAS' instead.
      return
    end

    # normal command in sequence
    if seqNo > 0
      @inSeqNumber = seqNo
    end
    NodeAgent.instance.execCommand(argArray)
  end

end # TcpServerCommunicator


#
# This sub-class TcpCommunicator defines a NA Communicator, which will act as a TCP Client. 
# In this design, the NH will act as a TCP server, to which the NA will connect. 
#
class TcpCommunicator < Communicator

  #
  # Send a message
  #
  # - message = the text message to send
  #
  def send(*msgArray)
    send!(0, *msgArray)
  end

  #
  # If agent tunes into reliable multicast late, the handler
  # sends in its initial message the highest seq number already
  # used. This means any message with this seq# or any lower can be
  # ignored.
  #
  # - ignoreCnt = sequence number below which a message can be ignored
  #
  def ignoreUpTo(ignoreCnt)
    debug "Ignoring first #{ignoreCnt} commands"
    @inSeqNumber = ignoreCnt
  end

  #
  # Send a heartbeat back to the handler
  #
  def sendHeartbeat()
    if NodeAgent.instance.connected?
      send!(:HB, -1, -1, -1, -1)
    else
      # haven't heard from nodeHandler yet, resend initial message
      sendWHOAMI
    end
  end

  private

  #
  # Send a message
  #
  # - seqNo = sequence number of the message to send
  # - msgArray = the array of text to send
  #
  def send!(seqNo, *msgArray)
    message = "#{NodeAgent.instance.agentName} 0 #{LineSerializer.to_s(msgArray)}"
    debug("Send message: '#{message}'")
    @sock.write(message)
  end

  #
  # Initialize the socket through which to send and receive messages
  #
  # - params = list of parameters used to initialize the socket ('local_addr', 'handler_port', 'handler_addr')
  #
  def initialize(params)

    super
    @params = params
    @@localAddr = getParam(@params, 'local_addr', false)
    @handlerPort = getParam(@params, 'handler_port')
    @handlerAddr = getParam(@params, 'handler_addr')

    debug("Connecting to handler at '#{@handlerAddr}:#{@handlerPort}'")
    @sock = TCPSocket.open(@handlerAddr, @handlerPort)
    debug("Connected");

    # Create two threads, one for receiving packets and one for
    # processing them. Put a queue in between
    queue = Queue.new
    Thread.new() {
      begin
        while true do
          Thread.current.priority = +1
          debug("Ready to receive commands")
          cmd = @sock.recvfrom(1024)[0]
          debug("Received #{cmd.length} bytes from socket")
          cmd.each {|line|
            debug('Pushed onto queue (l:', queue.length, '): ', line)
            queue.push(line)
          }
        end
      rescue EOFError
        # do nothing
      rescue Exception => err
        error("While listening for commands: #{err}")
      ensure
        @sock.close
      end
    }
    Thread.new() {
      while true do
        #Thread.current.priority = +2
        begin
          debug("Popping message (l:", queue.length, ')')
          line = queue.deq
          debug("Process message (l:", queue.length, "): '", line, "'")
          a = LineSerializer.to_a(line)
          t = Time.now
          processCommand(a)
          debug("Time taken to process command: ", Time.now - t)
          Thread.pass
        rescue Exception => err
          bt = err.backtrace.join("\n\t")
          error("While processing command '#{line}' Error: '#{err}'")
          debug("While processing command '#{line}' \n\tError: #{err}\n\t#{bt}")
        end
      end
    }
    @heartbeatInterval = getParam(@params, 'heartbeat_interval', false)
    if (@heartbeatInterval != nil)
      Thread.new() {
  while true
    begin
      debug("Heartbeat: Sleeping for ", @heartbeatInterval)
      t = Time.now
      sleep @heartbeatInterval
      debug "Heartbeat: Sending Heartbeat after ", Time.now - t
      sendHeartbeat
    rescue Exception => err
      bt = err.backtrace.join("\n\t")
      error("While sending heartbeat. Error: '#{err}'")
      debug("While sending heartbeat. Error: #{err}\n\t#{bt}")
    end
  end
      }
    end

    sendWHOAMI
  end

  #
  # Process an incoming command from the NH. 
  # Commands should be of the form:
  #
  #   sequenceNo target command arg1 arg2 ...
  #
  # - argArray = array of received command line arguments
  #
  def processCommand(argArray)
    if argArray.size < 3
      raise "Command is too short '#{argArray.join(' ')}'"
    end

    seqNo = argArray.delete_at(0).to_i.abs
    p ">> seq #{seqNo} #{@inSeqNumber}"
    if (seqNo > 0 && seqNo <= @inSeqNumber)
      # already got that one
      return
    end

    # normal command in sequence
    if seqNo > 0
      @inSeqNumber = seqNo
    end
    NodeAgent.instance.execCommand(argArray)
  end

end # TcpCommunicator


#
# This sub-class MCCommunicator defines a NA Communicator, 
# which will communicate the NH over an unreliable Multicast channel.
#
class MCCommunicator < Communicator

  #
  # Send a message
  #
  # - message = the text message to send
  #
  def send(*msgArray)
    @lockSeqNumber.synchronize {
      send!(@outSeqNumber += 1, *msgArray)
    }
  end

  #
  # Resend a message and all following ones to the current
  # @outSeqNumber.
  #
  # This method starts a thread which sends the sequence of
  # messages spaced by RESEND_INTERVAL. If it is being called
  # before a previously created thread has finished, it will
  # return immediately and NOT create a new thread.
  #
  # - msgId = rirst message to resend
  #
  def resend(msgId)
    if (@resendThread != nil && @resendThread.alive?)
      return
    end
    @resendThread = Thread.new(msgId) { | msgId |
    @lockSeqNumber.synchronize {
      while msgId <= @outSeqNumber
        message = @messages[msgId]
        Communicator.instance.send(message)
        debug("Resend thread: Sleep for ", RESEND_INTERVAL)
        sleep RESEND_INTERVAL
        debug("Resend thread: Continuing")
        msgId += 1
      end
      debug("Resend thread: Finishing")
    }
    }
  end

  #
  # Send a "Resume and Quit" message to the stdIn of the OML Proxy Application
  # (the message effectively sent is 'OMLPROXY-RESUME')
  #
  def sendResumeAndQuit
    omlID = AgentCommands.omlProxyID
    debug "Sending RESUME to #{omlID}"
    ExecApp[omlID].stdin("OMLPROXY-RESUME")
  end
  
  #
  # Send a 'relaxed' heartbeat back to the handler
  # This is only possible when NH has requested this NA to 
  # allow disconnections to happen (e.g. experiment involving
  # mobile nodes that can be out of range of NH)
  # In this case, a HB message not acknowledged will not trigger a reset
  # but instead will put the NA in a 'temporary disconnected' state, where
  # it still sends HB (tries to reconnect), this state is left upon reconnection
  # with the NH
  #
  def sendRelaxedHeartbeat()

    if NodeAgent.instance.connected?
      # Check if we still hear from handler
      now = Time.now
      delta = now - @handlerTimestamp

      # NO - Then enter a 'temporary disconnected' state
      if (delta  > @handlerTimeout)
        if ((@timeoutCnt += 1) >= @timeoutCount)
          @tmpDisconnected = true
          debug "Heartbeat - Lost Handler - Node is now temporary Disconnected"
        end

      # YES - Then if we were previously disconnected, leave that state!
      else 
        if @tmpDisconnected
          @tmpDisconnected = false
          debug "Heartbeat - Found Handler - Node is now Reconnected"
        end
      end

      # Regardless of connection state, we keep sending HB
      @timeoutCnt = 0
      inCnt = @inSeqNumber > 0 ? @inSeqNumber : 0
      @lockSeqNumber.synchronize {
        send!(:HB, @outSeqNumber, inCnt, now.to_i, delta.to_i)
      }

      # Always check if Experiment is done AND we are not temporary disconnected
      #debug "TDEBUG - Check EXPDONE + !DISCONNECTED - #{NodeAgent.instance.expirementDone?} - #{!@tmpDisconnected}"
      if (NodeAgent.instance.expirementDone? && !@tmpDisconnected)
        debug "Heartbeat - Experiment Done and Node Reconnected"
        sendResumeAndQuit
        ### HACK - Waiting for OML Proxy to return a good 'DONE' to us
        Kernel.sleep 10
        sendEXPDONE
        NodeAgent.instance.reset
      end
    else # ---if NodeAgent.instance.connected?---
      # haven't heard from nodeHandler yet, resend initial message
      sendWHOAMI
    end
  end

  #
  # Send a heartbeat back to the handler
  #
  def sendHeartbeat()
    if NodeAgent.instance.connected?
      # Check if we still hear from handler
      now = Time.now
      delta = now - @handlerTimestamp
      if (delta  > @handlerTimeout)
        if ((@timeoutCnt += 1) >= @timeoutCount)
          error "Lost handler after #{delta}, will reset. Now: #{Time.now}"
          send!(0, :ERROR, :LOST_HANDLER, delta)
          NodeAgent.instance.reset
        else
          send!(0, :WARN, :ALMOST_LOST_HANDLER, @timeoutCnt, delta)
        end
      else
        @timeoutCnt = 0
        inCnt = @inSeqNumber > 0 ? @inSeqNumber : 0
        @lockSeqNumber.synchronize {
        send!(:HB, @outSeqNumber, inCnt, now.to_i, delta.to_i)
        }
      end
    else
    # haven't heard from nodeHandler yet, resend initial message
    sendWHOAMI
    end
  end

  #
  # If agent tunes into reliable multicast late, the handler
  # sends in its initial message the highest seq number already
  # used. This means any message with this seq# or any lower can be
  # ignored.
  #
  # - ignoreCnt = sequence number below which a message can be ignored
  #
  def ignoreUpTo(ignoreCnt)
    @inSeqNumber = ignoreCnt
    if (@inHighestNumber < ignoreCnt)
      @inHighestNumber = ignoreCnt
    end
  end

  #
  # This method is called when a packet with a higher seq
  # number has been received.
  # Right now we simply send a retry message, but in the future
  # may consider a random wait first to let other agents report
  # it first.
  #
  def requestRetry()
    if (@requestThread != nil && @requestThread.alive?)
      # already working on it
      return
    end
    @requestThread = Thread.new() {
      while (@inHighestNumber > @inSeqNumber)
        from = to = @inSeqNumber + 1
        while (@recvCache[to += 1] == nil)
        end
        send!(0, :RETRY, from, to - 1);

        debug("Request thread: Sleep for ", RETRY_INTERVAL)
        sleep RETRY_INTERVAL
        debug("Request thread: Continuing")
      end
     debug("Request thread: Finishing")
    }
  end

  #
  # Initialize the Multicast sockets through which to send and receive messages
  #
  # - params = list of parameters used to initialize the socket 
  #            ('local_addr', 'local_if', 'handler_port', 'handler_addr', 'listen_port', 'listen_addr')
  #
  def initialize(params) #initCommunication(sendAddr, sendPort, recvAddr, recvPort)

    super
    # TDEBUG
    @tmpDisconnected = false

    @params = params
    @@localAddr = getParam(@params, 'local_addr', false)
    @sendPort = getParam(@params, 'handler_port')
    @sendAddr = getParam(@params, 'handler_addr')
    @recvPort = getParam(@params, 'listen_port')
    @recvAddr = getParam(@params, 'listen_addr')
    @localIF = getParam(@params, 'local_if')

    if !Communicator.multicastAddress?(@sendAddr)
      raise "Expected 'handler_addr' to be a multicast address"
    end
    if !Communicator.multicastAddress?(@recvAddr)
      raise "Expected 'listen_addr' to be a multicast address"
    end

    @heartbeatInterval = getParam(@params, 'heartbeat_interval')

    @timeoutCount = getParam(@params, 'timeout_count')
    @handlerTimeout = getParam(@params, 'handler_timeout')

    @outCount = 0
    @sendLastTime = Time.now

    debug("Binding multicast sockets to interface '#{localAddr()}'")
    @sendSock = MulticastSocket.bind(0, localAddr())
    debug("Open send port #{@sendAddr}:#{@sendSock.addr.join('#')}");

    @recvSock = MulticastSocket.bind(@recvPort, localAddr())
    @recvSock.addMembership(@recvAddr)
    debug("Open receive port #{@recvAddr}:#{@recvSock.addr.join('#')}");

    # Create two threads, one for receiving packets and one for
    # processing them. Put a queue in between
    queue = Queue.new
    Thread.new() {
      begin
        while true do
          #Thread.current.priority = +1
          #debug("Ready to receive commands")
          cmd = @recvSock.recvfrom(1024)[0]
          #debug("Received #{cmd.length} bytes from socket")
          cmd.each {|line|
            #debug('Pushed onto queue (l:', queue.length, '): ', line)
	    line.chomp!
            queue.push(line)
          }
        end
      rescue EOFError
        # do nothing
      rescue Exception => err
        error("While listening for commands: #{err}")
      ensure
        @recvSock.close
      end
    }

    Thread.new() {
      # TDEBUG
      while true do
        #Thread.current.priority = +2
        begin
          #debug("Popping message (l:", queue.length, ')')
          line = queue.deq
          #debug("Process message (l:", queue.length, "): '", line, "'")
          a = LineSerializer.to_a(line)
          t = Time.now
          processCommand(a)
          debug("Time taken to process command: ", Time.now - t)
          #Thread.pass
        rescue Exception => err
          bt = err.backtrace.join("\n\t")
          error("While processing command '#{line}' Error: '#{err}'")
          debug("While processing command '#{line}' \n\tError: #{err}\n\t#{bt}")
        end
      end
    }

    Thread.new() {
      while true
        begin
          #debug("Heartbeat: Sleeping for ", @heartbeatInterval)
          t = Time.now
          sleep @heartbeatInterval
          #debug "Heartbeat: Sending Heartbeat after ", Time.now - t
          if NodeAgent.instance.allowDisconnection? 
            sendRelaxedHeartbeat
          else
            sendHeartbeat
          end
        rescue Exception => err
          bt = err.backtrace.join("\n\t")
          error("While sending heartbeat. Error: '#{err}'")
          debug("While sending heartbeat. Error: #{err}\n\t#{bt}")
        end
      end
    }
  end

  #
  # Process an incoming command from the NH. 
  # Commands should be of the form:
  #
  #   sequenceNo target command arg1 arg2 ...
  #
  # - argArray = array of received command line arguments
  #
  def processCommand(argArray)

    if argArray.size < 3
      raise "Command is too short '#{argArray.join(' ')}'"
    end
    prevTS = @handlerTimestamp
    @handlerTimestamp = Time.now # we still hear the handler
    #debug("ping from handler after: #{@handlerTimestamp - prevTS}")
    if (argArray[1] == "NOBODY") || (NodeAgent.instance.connected? == false && NodeAgent.instance.isForMe(argArray[1]) == false)
      return
    end

    seqNo = argArray.delete_at(0).to_i
    isRetry = (seqNo < 0) # retries have negative seqNo
    seqNo = seqNo.abs
    if (seqNo > @inHighestNumber)
      @inHighestNumber = seqNo
    end

    # check if we skipped a command
    if (!NodeAgent.instance.connected? && seqNo != 0)
      # agent is not connected, so simply record
      # message for later use and return
      @recvCache[seqNo] = argArray # cache for catching up
      return
    elsif seqNo == 0
      # this is a "best effort"  request, process it if we can
      # pretend it's the last seqNo to keep the following code happy
      seqNo = @inSeqNumber
    elsif (seqNo <= @inSeqNumber)
      # already got that one
      #debug "Already got message #{seqNo}"
      return
    elsif (seqNo > @inSeqNumber + 1)
      # we missed some. Send retry for
      # first missed one.
      @recvCache[seqNo] = argArray # cache for catching up
      requestRetry()
      return
    end
    # normal command in sequence
    @inSeqNumber = seqNo
    NodeAgent.instance.execCommand(argArray)

    # process any early messages in sequence
    while (NodeAgent.instance.connected? && (argArray = @recvCache[seqNo += 1]) != nil)
      debug "Catching up #{seqNo}"
      @inSeqNumber = seqNo
      execCommand(argArray)
      @recvCache.delete(seqNo)
    end
  end

  #
  # Reset this Communicator
  #
  def reset
    super
    @messages = Array.new # keep all messages

    @recvCache = Hash.new # maintain a cache of "early" messages
    @resendThread = nil

    @requestThread = nil
    @handlerTimestamp = Time.now

    # Thierry: This mutex protect access to @outSeqNumber
    # it avoids cases where the 'HB thread' sends a HB with seqNum X while the 'main thread' is still sending
    # the message with seqNum X (-> NH would receive HB before msg -> would erroneously think 'out of sequence')
    @lockSeqNumber = Mutex.new

    # keeping track of seq numbers of
    # in and outgoing communication
    @lockSeqNumber.synchronize {
    @outSeqNumber = 0
    }
    @inSeqNumber = -1
    @inHighestNumber = -1

    @timeoutCnt = 0
  end

  #
  # Send a message
  #
  # - seqNo = sequence number of the message to send
  # - msgArray = the array of text to send
  #
  def send!(seqNo, *msgArray)
    message = "#{NodeAgent.instance.agentName} #{seqNo} #{LineSerializer.to_s(msgArray)}"
    if (seqNo > 0)
      @messages[seqNo] = message
    end
    #debug("Send message(#{@sendAddr}:#{@sendPort}): '#{message}'")
    @sendSock.send(message, 0, @sendAddr, @sendPort)
    return seqNo
  end

  #
  # Return the address and port this Communicator using to send
  # commands to the corresponding NH entity
  #
  # [Return] an Array of the form [addr, port]
  #
  def getSenderAddress()
    return [@sendAddr, @sendPort]
  end

  #
  # Return the address and port this Communicator using to listen
  # on for incoming commands
  #
  # [Return] an Array of the form [addr, port]
  #
  def getListenAddress()
    return [@recvAddr, @recvPort]
  end

  #
  # Send a message over the Multicast channel (through the sendSock)
  #
  # - message = the message to send
  #
  def sendSockMsg(message)
    last = @sendLastTime
    @sendLastTime = Time.now
    debug(@sendLastTime - last, ':', @sendAddr, '@', @sendPort, ': ', message)
    @sendSock.send(message, 0, @sendAddr, @sendPort)
  end
  
  #
  # Return the details of the Socket used to send messages over the Multicast channel
  #
  # [Return] the send Sock, the IP address, and the Port used
  # 
  def getSendSockAttr
    return @sendSock, @sendAddr, @sendPort
  end

  # Unused
  # NOTE: Shall we remove this, or is it a placeholder for future extention?
  def recvSockMsg
  end

end # MCCommunicator
