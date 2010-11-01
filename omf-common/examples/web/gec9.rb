#
# Copyright (c) 2010 National ICT Australia (NICTA), Australia
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
# = gpswalk.rb
#
# == Description
#
# Define a few graphs for a gps walk around Redfern
#

$TITLE = "Parknet"


$DEF_OPTS = {
  :debug => false,
  :port => 4000,
  :showTabs => [:graph3, :code],
  :serviceURL => 'http://localhost:5053/result2/query',
  :repoName => 'gpswalk-eveleigh-sample',
  :repoName => 'disconnecttest'
}


def initGraphs(opts)
  
  repo = opts[:repo]
  OMF::Common::Web::Graph3.addGraph('Position (T)', 'table2', {:updateEvery => 5}) do |g|
    skip = g.session['skip'] ||= 0
    s = []
    t = repo[:GPSlogger_gps_data]
    q = t.project(t[:time], t[:lat], t[:lon]) 
    q.skip(skip).take(10000).each do |r|  # skip always needs a take as well
      s << r.tuple
    end
    g.session['skip'] += s.length
    sopts = {:labels => ["Time", "Lat", "Lon"]} #, :record_id => 0}
    g.addSeries(s, sopts)
  end
  
  gopts = {
    :updateEvery => 3,
    :zoom => 14
  }
  OMF::Common::Web::Graph3.addGraph('Position (M)', 'map2', gopts) do |g|
    skip = g.session['skip'] ||= 0
    traces = {}
    t = repo[:GPSlogger_gps_data]
    q = t.project(t[:oml_sender_id], t[:time], t[:lat], t[:lon]) 
    q.skip(skip).take(5000).each do |r|  # skip always needs a take as well
      car, time, lat, lon = r.tuple
      t = traces[car] ||= []
      t << [time, lat, lon]
      skip += 1
    end
    g.session['skip'] += skip
    sopts = {:labels => ["Time", "Lat", "Lon"]} #, :record_id => 0}
    traces.each do |name, values|
      g.addSeries(values, {:label => name})
    end
  end


  OMF::Common::Web::Graph3.addGraph('WiMAX (T)', 'table2', {:updateEvery => 5}) do |g|
    skip = g.session['skip'] ||= 0
    s = []
    t = repo[:wimaxmonitor_wimaxstatus]
    q = t.project(t[:sender_hostname], t[:timestamp_epoch], t[:signal], t[:rssi], t[:cinr]) 
    q.skip(skip).take(1000).each do |r|  # skip always needs a take as well
      #id, time, sensor = r.tuple
      s << r.tuple
    end
    g.session['skip'] += s.length
    sopts = {:labels => ["Terminal", "Timestamp", "Signal", "RSSI", "CINR"]} #, :record_id => 0}
    g.addSeries(s, sopts)
  end

  opts = {
      :updateEvery => 3,    
      :xLabel => "Time [sec]",      
      :yLabel =>  "RSSI"
#      :yMin => 0
  }
  OMF::Common::Web::Graph3.addGraph('WiMAX (RSSI)', 'line_chart_focus2', opts) do |g|
    skip = g.session['skip'] ||= 0
    traces = {}
    t = repo[:wimaxmonitor_wimaxstatus]
    q = t.project(t[:sender_hostname], t[:timestamp_epoch], t[:rssi]) 
    q.skip(skip).take(1000).each do |r|  # skip always needs a take as well
      #id, time, sensor = r.tuple
      host, ts, rssi = r.tuple
      t = traces[host] ||= []
      t << [ts, rssi]
      skip += 1
    end
    g.session['skip'] += skip

    traces.each do |name, values|
      g.addSeries(values, :label => name)
    end
  end

  opts = {
      :updateEvery => 3,    
      :xLabel => "Time [sec]",      
      :yLabel =>  "CINR"
#      :yMin => 0
  }
  OMF::Common::Web::Graph3.addGraph('WiMAX (CINR)', 'line_chart_focus2', opts) do |g|
    skip = g.session['skip'] ||= 0
    traces = {}
    t = repo[:wimaxmonitor_wimaxstatus]
    q = t.project(t[:sender_hostname], t[:timestamp_epoch], t[:cinr]) 
    q.skip(skip).take(1000).each do |r|  # skip always needs a take as well
      #id, time, sensor = r.tuple
      host, ts, cinr = r.tuple
      t = traces[host] ||= []
      t << [ts, cinr]
      skip += 1
    end
    g.session['skip'] += skip

    traces.each do |name, values|
      g.addSeries(values, :label => name)
    end
  end

  opts = {
      :updateEvery => 3,    
      :xLabel => "Time [sec]",      
      :yLabel =>  "Sensor Reading",
      :yMin => 0
  }
  gtype = 'line_chart_focus'
  gtype = 'line_chart_focus2'
  OMF::Common::Web::Graph3.addGraph('Sensor (G)', gtype, opts) do |g|
    skip = g.session['skip'] ||= 0
    s = []
    t = repo[:gpsapp_sensor]
    q = t.project(t[:oml_sender_id], t[:sensortime_integer], t[:sensorreading]) 
    q.skip(skip).take(500).each do |r|  # skip always needs a take as well
      id, time, sensor = r.tuple
      s << [time, sensor.slice(1..-1).to_i ]
    end
    g.session['skip'] += s.length
    g.addSeries(s, :label => "Car #1")
  end

  
  opts = {
      :updateEvery => 3,    
      :xLabel => "Time [sec]",      
      :yLabel =>  "Received Traffic [Kbytes]",
      :yMin => 0
  }
  gtype = 'line_chart_focus'
  #gtype = 'line_chart'
  OMF::Common::Web::Graph3.addGraph('Sensor', gtype, opts) do |g|
    wifi = []
    umts = []
    start_ts = nil
#    cnt = 0
#    r = OMF::Common::OML::Table[:traffic].project(:oml_ts_server)
#    m = r.methods.sort
    #last_wifi = last_umts = nil
    res = []
    skip = g.session['skip'] ||= 0
    repo[:gpsnew_sensor].project(:oml_ts_server, :wifi_in_bytes, :umts_in_bytes) \
        .skip(skip).take(5000).each do |r|
      ts, w, u = r.tuple
      
      wifi << [ts, w]
      umts << [ts, u]
    end
    g.session['skip'] += wifi.length
    g.addSeries(wifi, :label => "WiFi")
    g.addSeries(umts, :label => "UMTS")
  end

  opts = {
      #:prefix => "Prefix text",
      :xLabel => "Time [sec]",      
      :yLabel =>  "Traffic [Kbytes]",
      #:yMin => 0
  }
#  OMF::Common::Web::Graph3.addGraph('Test', 'table', opts) do |g|
#
#    skip = g.session['skip'] ||= 0
#    s = []
#    mc = repo[:mediacontent]
#    mc2 = mc.alias
#    accessed = mc2.where(mc2[:status].eq('Accessed'))#.project(mc2[:status])
#    q = mc.project(mc[:oml_ts_server], mc[:name]).join(accessed).on(mc[:name].eq(mc2[:name]))
#    q.skip(skip).take(10000).each do |r|
#      s << r.tuple
#    end
#    puts s.inspect
#    g.session['skip'] += s.length
#    sopts = {:labels => ["Time", "Name", "URL", "Status"]} #, :record_id => 0}
#    g.addSeries(s, sopts)
#  end
end

def initCode(opts)
  c = {
    :uri => 'exp:gec9',
    :content => File.new("#{File.dirname(__FILE__)}/gec9_script.rb").read,
    :mime_type => "/text/ruby"
  }
  OMF::Common::Web::Code.addScript(c)
end

load "#{File.dirname(__FILE__)}/tabbed_server.rb"
