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
# = prefetching.rb
#
# == Description
#
# Define a few graphs for the ParkNet database.
#

$TITLE = "ParkNet"


$DEF_OPTS = {
  :debug => false,
  :port => 4000,
  :serviceURL => 'http://localhost:5053/result2/query',
  :repoName => 'parknet_2010-09-24~14-36-26'
}


def initGraphs(opts)
  
  repo = opts[:repo]
  OMF::Common::Web::Graph3.addGraph('Sensor (T)', 'table2', {:updateEvery => 5}) do |g|
    skip = g.session['skip'] ||= 0
    s = []
    t = repo[:gpsapp_sensor]
    q = t.project(t[:oml_sender_id], t[:sensortime_integer], t[:sensorreading]) 
    q.skip(skip).take(100).each do |r|  # skip always needs a take as well
      id, time, sensor = r.tuple
      s << [id, time, sensor.slice(1..-1).to_i ]
    end
    g.session['skip'] += s.length
    sopts = {:labels => ["Car#", "Time", "Sensor"]} #, :record_id => 0}
    g.addSeries(s, sopts)
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

  OMF::Common::Web::Graph3.addGraph('GPS (T)', 'table2', {:updateEvery => 5}) do |g|
    skip = g.session['skip'] ||= 0
    s = []
    t = repo[:gpsapp_gps]
    q = t.project(t[:oml_sender_id], t[:systemtime_integer],
                  t[:latitude], t[:longitude], t[:speed]) 
    q.skip(skip).take(10000).each do |r|  # skip always needs a take as well
      s << r.tuple
    end
    g.session['skip'] += s.length
    sopts = {:labels => ["Car#", "Time", "Lat", "Lon", "Speed"]} #, :record_id => 0}
    g.addSeries(s, sopts)
  end

  gopts = {}
  #{:updateEvery => 5}
  OMF::Common::Web::Graph3.addGraph('GPS (M)', 'map2', gopts) do |g|
    skip = g.session['skip'] ||= 0
    s = []
    t = repo[:gpsapp_gps]
    q = t.project(t[:oml_sender_id], t[:latitude], t[:longitude], t[:speed]) 
    q.skip(skip).take(1000).each do |r|  # skip always needs a take as well
      id, lat, lon, speed = r.tuple
      unless lat == -2.0 || lon == -2.0
        s << [id, lat, lon, speed]
      end
    end
    puts s.inspect
    g.session['skip'] += s.length
    sopts = {} #:labels => ["Car#", "Time", "Lat", "Lon", "Speed"]} #, :record_id => 0}
    g.addSeries(s, sopts)
  end

  
  opts = {
      :updateEvery => 3,    
      :xLabel => "Time [sec]",      
      :yLabel =>  "Received Traffic [Kbytes]",
      :yMin => 0
  }
  gtype = 'line_chart_focus'
  gtype = 'line_chart_focus2'
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
end

load "#{File.dirname(__FILE__)}/tabbed_server.rb"