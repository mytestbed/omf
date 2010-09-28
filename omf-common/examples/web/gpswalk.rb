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

$TITLE = "Walk Around Redfern"


$DEF_OPTS = {
  :debug => false,
  :port => 4000,
  :serviceURL => 'http://localhost:5053/result2/query',
  :repoName => 'gpswalk-eveleigh-sample'
}


def initGraphs(opts)
  
  repo = opts[:repo]
  OMF::Common::Web::Graph3.addGraph('Position (T)', 'table', {:updateEvery => 5}) do |g|
    skip = g.session['skip'] ||= 0
    s = []
    t = repo[:GPSlogger_gps_data]
    q = t.project(t[:time], t[:lat], t[:lon]) 
    q.skip(skip).take(10000).each do |r|  # skip always needs a take as well
    puts r.tuple.inspect
      s << r.tuple
    end
    g.session['skip'] += s.length
    sopts = {:labels => ["Time", "Lat", "Lon"]} #, :record_id => 0}
    g.addSeries(s, sopts)
  end

  OMF::Common::Web::Graph3.addGraph('GPS (T)', 'table', {:updateEvery => 5}) do |g|
    skip = g.session['skip'] ||= 0
    s = []
    t = repo[:gpsnew_gps]
    q = t.project(t[:oml_sender_id], t[:systemtime_integer],
                  t[:latitude], t[:longitude], t[:speed]) 
    q.skip(skip).take(10000).each do |r|  # skip always needs a take as well
      s << r.tuple
    end
    puts s.inspect
    g.session['skip'] += s.length
    sopts = {:labels => ["Car#", "Time", "Lat", "Lon", "Speed"]} #, :record_id => 0}
    g.addSeries(s, sopts)
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
  OMF::Common::Web::Graph3.addGraph('App Traffic', gtype, opts) do |g|
    inT = []
    outT = []
    skip = g.session['skip'] ||= 0
    repo[:traffic]\
        .project(:oml_ts_server, :app_in_bytes, :app_out_bytes)\
        .skip(skip).take(1000).each do |r|
      ts, i, o = r.tuple
      inT << [ts, i / 1000]
      outT << [ts, o / 1000]
    end
    g.session['skip'] += inT.length
    g.addSeries(inT, :label => "Incoming")
    g.addSeries(outT, :label => "Outgoing")
  end
  
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

load "#{File.dirname(__FILE__)}/tabbed_server.rb"