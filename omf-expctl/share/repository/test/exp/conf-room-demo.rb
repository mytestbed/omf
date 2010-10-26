#
# Copyright (c) 2006-2010 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2010 WINLAB, Rutgers University, USA
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

defProperty('hrnPrefix', "omf.nicta.node", "Prefix to use for the HRN of resources")
defProperty('resources', "[1,2,3,4,5,8,9,10,11,12,13]", "List of IDs for the resources to use as senders")
defProperty('receiver', "6", "ID for the resource to use as a receiver")
defProperty('groupSize', 4, "Number of resources to put in each group of senders")
defProperty('rate', 300, 'Bits per second sent from senders')
defProperty('packetSize', 256, 'Byte size of packets sent from senders')
defProperty('wifiType', "g", "The type of WIFI to use in this experiment")
defProperty('channel', '6', "The WIFI channel to use in this experiment")
defProperty('netid', "confroom", "The ESSID to use in this experiment")
defProperty('stepDuration', 60, "The duration of each step of this conf-room")

# Define the Receiver
defGroup('Receiver', "#{property.hrnPrefix}#{property.receiver}") do |node|
  node.addApplication("test:app:otr2") do |app|
    app.setProperty('udp:local_host', '%net.w0.ip%')
    app.setProperty('udp:local_port', 3000)
    app.measure('udp_in', :samples => 1)
  end
  node.net.w0.mode = "master"
  node.net.w0.type = property.wifiType
  node.net.w0.channel = property.channel
  node.net.w0.essid = property.netid
  node.net.w0.ip = "192.168.0.254"
end

# Define each Sender groups
groupList = []
res = eval(property.resources.value)
groupNumber = res.size >= property.groupSize ? (res.size.to_f / property.groupSize.value.to_f).ceil : 1
(1..groupNumber).each do |i|
  list = []
  (1..property.groupSize).each do |j| popped = res.pop ; list << popped if !popped.nil?  end
  senderNames = list.collect do |id| "#{property.hrnPrefix}#{id}" end 
  senders = senderNames.join(',')

  info "Group Sender #{i}: '#{senders}'"
  groupList << "Sender#{i}"
  defGroup("Sender#{i}", senders) do |node|
    node.addApplication("test:app:otg2") do |app|
      app.setProperty('udp:local_host', '%net.w0.ip%')
      app.setProperty('udp:dst_host', '192.168.0.254')
      app.setProperty('udp:dst_port', 3000)
      app.setProperty('cbr:size', property.packetSize)
      app.setProperty('cbr:rate', property.rate)
      app.measure('udp_out', :samples => 1)
    end
    node.net.w0.mode = "managed"
    node.net.w0.type = property.wifiType
    node.net.w0.channel = property.channel
    node.net.w0.essid = property.netid
    node.net.w0.ip = "192.168.0.%index%"
  end 
end

onEvent(:ALL_UP_AND_INSTALLED) do |event|
  wait 10
  group('Receiver').startApplications
  wait 10
  (1..groupNumber).each do |i|
    group("Sender#{i}").startApplications
    wait property.stepDuration
  end
  wait 60
  (1..groupNumber).each do |i|
    group("Sender#{i}").stopApplications
    wait property.stepDuration
  end
  group('Receiver').stopApplications
  Experiment.done
end


addTab(:defaults)
addTab(:graph2) do |tab|
  opts = { :postfix => %{Sender index for incoming UDP traffic = F(time)}, :updateEvery => 1 }
  tab.addGraph("Incoming UDP", opts) do |g|
    data = Hash.new
    index = 1
    mpIn = ms('udp_in')
    mpIn.project(:oml_ts_server, :src_host, :seq_no).each do |sample|
      time, src, seq = sample.tuple
      if data[src].nil? 
        data[src] = [index,[]] 
        index += 1
      end
      data[src][1] << [time, data[src][0]] 
    end
    data.each do |src,value|
      g.addLine(value[1], :label => "Node #{value[0]}") 
    end
  end
end

