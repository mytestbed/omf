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
defProperty('duration', 60, "Duration of the experiment")
defProperty('graph', false, "Display graph or not")

defGroup('Sender', property.res1) do |node|
  node.addApplication("test:app:otg2") do |app|
    app.setProperty('udp:local_host', '192.168.0.2')
    app.setProperty('udp:dst_host', '192.168.0.3')
    app.setProperty('udp:dst_port', 3000)
    app.measure('udp_out', :samples => 1)
  end
  node.net.e0.ip = "192.168.0.2"
end

defGroup('Receiver', property.res2) do |node|
  node.addApplication("test:app:otr2") do |app|
    app.setProperty('udp:local_host', '192.168.0.3')
    app.setProperty('udp:local_port', 3000)
    app.measure('udp_in', :samples => 1)
  end
  node.net.e0.ip = "192.168.0.3"
end

onEvent(:ALL_UP_AND_INSTALLED) do |event|
  info "This is my first OMF experiment"
  wait 10
  allGroups.startApplications
  info "All my Applications are started now..."
  wait property.duration
  allGroups.stopApplications
  info "All my Applications are stopped now."
  Experiment.done
end

if property.graph.value
  addTab(:defaults)
  addTab(:graph2) do |tab|
    opts = { :postfix => %{This graph shows the Sequence Number from the UDP traffic.}, :updateEvery => 1 }
    tab.addGraph("Sequence_Number", opts) do |g|
      dataOut = Array.new
      dataIn = Array.new
      mpOut = ms('udp_out')
      mpIn = ms('udp_in')
      mpOut.project(:oml_ts_server, :seq_no).each do |sample|
        dataOut << sample.tuple
      end
      mpIn.project(:oml_ts_server, :seq_no).each do |sample|
        dataIn << sample.tuple
      end
      g.addLine(dataOut, :label => "Sender (outgoing UDP)")
      g.addLine(dataIn, :label => "Receiver (incoming UDP)")
    end
  end
end

