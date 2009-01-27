#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
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
#
# Define a prototype of a node containing both, a sender and receiver.
#

defPrototype("test:proto:sender_receiver", "Send&Receive") { |p|
  p.description = "A node which transmit a stream of packets as well as listens for one"

  # Sender
  p.defProperty('senderProtocol', 'Protocol to use', 'udp')
  p.defProperty('senderGenerator', 'Generator to use', 'cbr')
  p.defProperty('destinationHost', 'Host to send packets to')
  p.defProperty('packetSize', 'Size of packets', 1000)
  p.defProperty('rate', 'Number of bits per second', 1000)
  p.defProperty('broadcast','broadcast or not', 'off')

  # Receiver
  p.defProperty('receiverProtocol', 'Protocol to use', 'udp')
  p.defProperty('receiverPort', 'Port to listen on',4000)
  p.defProperty('localHostname', 'My own ID for libmac filter','localhost')


  p.addPrototype("test:proto:sender", {
     'protocol' => p.bindProperty('senderProtocol'),
     'generator' => p.bindProperty('senderGenerator'),
     'destinationHost' => p.bindProperty('destinationHost'),
     'packetSize' => p.bindProperty('packetSize'),
     'rate' => p.bindProperty('rate'),
     'broadcast' => p.bindProperty('broadcast')
  })

  p.addPrototype("test:proto:receiver", {
     'protocol' => p.bindProperty('receiverProtocol'),
     'port' => p.bindProperty('receiverPort'),
     'hostname' => p.bindProperty('localHostname')
  })
}

