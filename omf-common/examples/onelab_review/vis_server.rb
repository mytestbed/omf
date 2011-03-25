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
# Define a few graphs for the prefetching database.
#

$TITLE = "Onelab Review Demo"

require 'digest/md5'

$DEF_OPTS = {
  :debug => false,
  :port => 4000,
  :serviceURL => 'http://srv.mytestbed.net:5053/result2/query',
  :serviceURL => 'http://nitlab.inf.uth.gr:5053/result2/query',  
  :repoName => 'ol_rtt',
  :repoName => 'ol2',
  # Starting time for most graphs
#  :startTime => 2e6
}

$CACHE = {}


def initGraphs(opts)
  lineChart = 'line_chart_focus2'
  lineChart = 'line_chart2'
  
  
  repo = opts[:repo]
  startTime = opts[:startTime] || 0
  OMF::Common::Web::Graph3.addGraph('Roundtrip (T)', 'table2', {:updateEvery => 3}) do |g|
    skip = g.session['skip'] ||= 0
    s = []
    t = repo[:rtt_roundtrip]
    t.project(t[:oml_ts_server], t[:sender], t[:receiver], t[:roundtrip]) \
        .skip(skip).take(200).each do |r|  # skip always needs a take as well
      s << r.tuple
    end
    g.session['skip'] += s.length
    sopts = {:labels => ["Time", "From", "To", "Delay"]} ##, :record_id => 0}
    g.addSeries(s, sopts)
  end
  
  opts = {
      :updateEvery => 3,    
      :xLabel => "Time [sec]",      
      :yLabel =>  "RTT"
#      :yMin => 0
  }
  OMF::Common::Web::Graph3.addGraph('Roundtrip (G)', lineChart, opts) do |g|
begin
    skip = g.session['skip'] ||= 0
    take = 10000
    traces = {}
    cache = $CACHE[:rtt] ||= []
    do_cache = false
    proc = lambda() do |r|  # skip always needs a take as well
      #id, time, sensor = r.tuple
      if do_cache
        cache << r.dup
        skip += 1
      end
      ts, from, to, rtt = r.tuple      
      t = traces[from] ||= []
      t << [ts, rtt]
    end

    if (csize = cache.size) > skip
      cache.slice(skip, take).each(&proc)
      skip += csize
      take -= csize
    end
    if (take > 0)
      do_cache = true
#      t = repo[:wimaxmonitor_wimaxstatus]
#      q = t.project(t[:sender_hostname], t[:timestamp_epoch], t[:cinr]) 
#      q.skip(skip).take(take).each(&proc)
      
      t = repo[:rtt_roundtrip]
      q = t.project(t[:oml_ts_server], t[:sender], t[:receiver], t[:roundtrip]) 
      q.skip(skip).take(take).each(&proc)

    end
    g.session['skip'] = skip

    traces.each do |name, values|
      puts ">>>>> #{name}:#{values.inspect}"
      g.addSeries(values, :label => name)
    end
rescue Exception => ex
  puts "ERRROR: #{ex}"
  puts ex.backtrace
end
  end
end

load "#{File.dirname(__FILE__)}/../web/tabbed_server.rb"
