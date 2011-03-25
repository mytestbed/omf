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

  :clamp => 1.0,    # max rtt value to display on line graphs

  :sleep_between_queries => 2  # time in seconds to wait before next query
  # Starting time for most graphs
#  :startTime => 2e6
}

$CACHE = {}


def initGraphs(opts)
  maintain_cache(opts)

  lineChart = 'line_chart_focus2'
  
  
  startTime = opts[:startTime] || 0
  OMF::Common::Web::Graph3.addGraph('Roundtrip (T)', 'table2', {:updateEvery => 3}) do |g|
    take = 5000
    if s = get_slice(take, g)
      sopts = {:labels => ["Time", "From", "To", "Delay"]} ##, :record_id => 0}
      g.addSeries(s, sopts)
    end
  end
  
  gopts = {
      :updateEvery => 1,    
      :xLabel => "Time [sec]",      
      :yLabel =>  "RTT"
#      :yMin => 0
  }
  OMF::Common::Web::Graph3.addGraph('Roundtrip (G)', 'line_chart2', gopts) do |g|
    take = 5000
    create_graph(take, g, opts)
  end

  OMF::Common::Web::Graph3.addGraph('Roundtrip (GZF)', 'line_chart_focus2', gopts) do |g|
    take = 50000
    create_graph(take, g, opts)
  end
end

def create_graph(take, g, opts)
  if s = get_slice(take, g)
    traces = {}
    s.each do |r|
      ts, from, to, rtt = r
      if rtt > opts[:clamp]  # clamp
        rtt = opts[:clamp]
      end
      t = traces[from] ||= []
      t << [ts, rtt]
    end
    traces.each do |name, values|
      #puts ">>>>> #{name}:#{values.inspect}"
      g.addSeries(values, :label => name)
    end
  end
end

def get_slice(take, g)
  skip = g.session['skip'] ||= 0
  cache = $CACHE[:rtt]

  s = nil
  cache[:mutex].synchronize do
    data = cache[:data]
    if (csize = data.size) > skip
      s = data.slice(skip, take)
      skip += csize
      take -= csize
    end
  end
  g.session['skip'] += s.length if s
  s
end

require 'thread'
def maintain_cache(opts)
  Thread.new do
    begin
      repo = opts[:repo]

      skip = 0
      take = 10000
      cache = $CACHE[:rtt] ||= {}
      cache[:mutex] = Mutex.new
      cache[:data] = []

      t = repo[:rtt_roundtrip]
      q = t.project(t[:oml_ts_server], t[:sender], t[:receiver], t[:roundtrip]) 

      loop do
        a = []
        q.skip(skip).take(take).each do |r|
          a << r.tuple.dup
          skip += 1
        end
        cache[:mutex].synchronize do
          cache[:data].concat a
        end

        sleep opts[:sleep_between_queries]  # time in seconds to wait before next query
      end

    rescue Exception => ex
      puts "ERRROR: #{ex}"
      puts ex.backtrace
    end
  end
end
    
load "#{File.dirname(__FILE__)}/../web/tabbed_server.rb"
