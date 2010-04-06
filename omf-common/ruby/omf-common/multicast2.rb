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
require 'socket'

#struct ip_mreq {
#        struct in_addr  imr_multiaddr;  /* IP multicast address of group */
#        struct in_addr  imr_interface;  /* local IP address of interface */
#};


class MulticastSocket < UDPSocket

  def MulticastSocket.bind(port = -1, mcInterface = nil)

    sock = open
#    sock.setMCInterface(mcInterface) if mcInterface != nil

    port = port.to_i
    if (port >= 0)
      host = unix? ? "0.0.0.0" : Socket.gethostname
      sock.bind(host, port)
    end
    sock.setMCInterface(mcInterface) if mcInterface != nil
    return sock
  end

  def MulticastSocket.unix?
    return RUBY_PLATFORM.include?('linux')
  end

  def addMembership(mcaddr)
    #mreq = convAddr(mcaddr) + Socket.gethostbyname(Socket.gethostname)[3]
    mreq = convAddr(mcaddr) # + "\000\000\000\000"
    setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, mreq)
  end

  def dropMembership(mcaddr)
    #mreq = convAddr(mcaddr) + Socket.gethostbyname(Socket.gethostname)[3]
    mreq = convAddr(mcaddr) # + "\000\000\000\000"
    setsockopt(Socket::IPPROTO_IP, Socket::IP_DROP_MEMBERSHIP, mreq)
  end

  def setMCTTL(ttl)
    setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_TTL, ttl)
  end

  def setMCLoop(loop)
    setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, loop)
  end



  def setMCInterface(int)
    @localAddress = Socket.gethostbyname(int)[3]
    setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF, @localAddress)
  end

  private

  def initialize()
    super()
    @localAddress = nil
  end

  def convAddr(a)
    h = nil
    case a
    when String
     h = a.split('.').collect! { |b| b.to_i }.pack('CCCC')

    when Array
      h = a.pack('CCCC')

    else
      raise "Bad address"
    end
  return h + getLocalAddress
  end

  @@gLocalAddress = nil

  def getLocalAddress
    a = @localAddress
    if a == nil
      if @@gLocalAddress == nil
        if MulticastSocket.unix?
          @@gLocalAddress = "\000\000\000\000"
        else
          @@gLocalAddress = Socket.gethostbyname(Socket.gethostname)[3]
        end
      end
      a = @@gLocalAddress
    end
    return a
  end



end

if $0 == __FILE__

  require 'optparse'


  port = 9002
#  port = 9008
  addr = '224.4.0.2'
  mcIf = nil
  doReceive = false

  opts = OptionParser.new
  opts.on("-a", "--addr MC_ADDRESS", "MC address to use") {|a| addr = a}
  opts.on("-p", "--port PORT", Integer, "Port to bind to") {|p| port = p; puts "port: #{p}"}
  opts.on("-m", "--mcIf PORT_IP", "Local interface to bind to") {|p| mcIf = p}
  opts.on("-r", "Receive on port [#{port}]", Integer) {doReceive = true}

  opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }

  begin
    rest = opts.parse(ARGV)
  rescue SystemExit
    exit
  rescue Exception => err
    puts "Error: #{err}"
    puts opts.to_s
    exit -1
  end


#  sock = MulticastSocket.bind(port)
  sock = MulticastSocket.bind(doReceive ? port : 0, mcIf)
  sock.addMembership(addr)
  puts sock

  if rest.length == 0
    puts "Send two message on #{addr}:#{port}"
    sock.send('Hello', 0, addr, port)
    sock.send('There', 0, addr, port)
  else
    msg = rest.join(" ")
    puts "Send msg '#{msg}' on #{addr}:#{port}"
    sock.send(msg, 0, addr, port)
  end

  if doReceive
    thread = Thread.start do
      while true
        p sock.recvfrom(256)
      end
    end

    p "Wait for remote packets #{sock.addr.join('#')}"
    sleep 15
  end
  sock.dropMembership(addr)
end
