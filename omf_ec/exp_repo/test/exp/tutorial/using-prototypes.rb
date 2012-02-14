#
# Copyright (c) 2006-2010 National ICT Australia (NICTA), Australia
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
# Tutorial experiment
#
defProperty('res1', 'omf.nicta.node1', "ID of sender node")
defProperty('res2', 'omf.nicta.node2', "ID of receiver node")
defProperty('duration', 30, "Duration of the experiment")
defProperty('graph', false, "Display graph or not")

defGroup('CBR_Sender', property.res1) do |node|
  options = { 'localHost' => '%net.w0.ip%',
              'destinationHost' => '192.168.255.255',
              'packetSize' => 256 }
  node.addPrototype("test:proto:cbr_generator", options)
end

defGroup('EXPO_Sender', property.res1) do |node|
  options = { 'localHost' => '%net.w0.ip%',
              'destinationHost' => '192.168.255.255',
              'packetSize' => 1024 }
  node.addPrototype("test:proto:expo_generator", options)
end

defGroup('Receiver', property.res2) do |node|
  node.addApplication("test:app:otr2") do |app|
    app.setProperty('udp:local_host', '192.168.255.255')
    app.setProperty('udp:local_port', 3000)
    app.measure('udp_in', :samples => 1)
  end
end

allGroups.net.w0 do |interface|
  interface.mode = "adhoc"
  interface.type = 'g'
  interface.channel = "6"
  interface.essid = "helloworld"
  interface.ip = "192.168.0.%index%"
end

onEvent(:ALL_UP_AND_INSTALLED) do |event|
  wait 10
  info "Starting the Receiver"
  group("Receiver").startApplications
  info "Starting the EXPO-traffic Sender"
  group("EXPO_Sender").startApplications
  wait property.duration
  info "Stopping the EXPO-traffic Sender"
  group("EXPO_Sender").stopApplications
  wait 5
  info "Starting the CBR-traffic Sender"
  group("CBR_Sender").startApplications
  wait property.duration
  info "Now stopping all everything"
  #allGroups.stopApplications
  group("CBR_Sender").stopApplications
  group("Receiver").stopApplications
  Experiment.done
end


if property.graph.value
  addTab(:defaults)
  addTab(:graph2) do |tab|
    opts1 = { :postfix => %{This graph shows the Sequence Number from CBR and EXP UDP traffic.}, :updateEvery => 1 }
    tab.addGraph("Sequence Number", opts1) do |g|
      dataOut = Hash.new
      mpOut = ms('udp_out')
      mpOut.project(:oml_sender_id, :oml_ts_server, :seq_no).each do |sample|
        sender, time, seq = sample.tuple
        dataOut[sender] = [] if dataOut[sender] == nil
        dataOut[sender] << [time,seq]
      end
      dataOut.each do |source, data|
        g.addLine(data, :label => "#{msSenderName[source]}")
      end
    end
    opts2 = { :postfix => %{This graph shows the Packet Size (bytes)from CBR and EXP UDP traffic.}, :updateEvery => 1 }
    tab.addGraph("Packet Size", opts2) do |g|
      dataOut = Hash.new
      mpOut = ms('udp_out')
      mpOut.project(:oml_sender_id, :oml_ts_server, :pkt_length).each do |sample|
        sender, time, plength = sample.tuple
        dataOut[sender] = [] if dataOut[sender] == nil
        dataOut[sender] << [time,plength]
      end
      dataOut.each do |source, data|
        g.addLine(data, :label => "#{msSenderName[source]}")
      end
    end
  end
end

