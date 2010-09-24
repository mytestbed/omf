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
# = tabbed_server.rb
#
# == Description
#

require 'optparse'
require 'omf-common/mobject'
require 'omf-common/web/webServer'
require 'omf-common/web/helpers'
require 'omf-common/oml/arel_remote'
#require 'omf-expctl/web/helpers'

require 'digest/md5'

default_opts = {
  :debug => false,
  :port => 4000,
  :serviceURL => 'http://localhost:5053/result2/query',
  :repoName => 'prefetching_4'
}

class ViewHelper < OMF::Common::Web::ViewHelper

  def self.page_title
    "Smart Caching Demo"
  end
end

def initGraphs(opts)
  
  repo = opts[:repo]
  OMF::Common::Web::Graph3.addGraph('Content', 'table', {:updateEvery => 3}) do |g|
    skip = g.session['skip'] ||= 0
    s = []
    repo[:mediacontent].project(:oml_ts_server, :name, :url, :status) \
        .skip(skip).take(10000).each do |r|  # skip always needs a take as well
      ts, name, url, status = r.tuple
      ourl = url
      if (url.length > 23)
        url = url.slice(0..9) + '...' + url.slice(-10 .. -1)
      end
      md5 = Digest::MD5.hexdigest(url)
      s << [md5, ts.to_int, name, "<a href='#{ourl}'>#{url}</a>", status]
    end
    g.session['skip'] += s.length
    sopts = {:labels => ["Time", "Name", "URL", "Status"], :record_id => 0}
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
  OMF::Common::Web::Graph3.addGraph('Download', gtype, opts) do |g|
    wifi = []
    umts = []
    start_ts = nil
#    cnt = 0
#    r = OMF::Common::OML::Table[:traffic].project(:oml_ts_server)
#    m = r.methods.sort
    #last_wifi = last_umts = nil
    res = []
    skip = g.session['skip'] ||= 0
    repo[:traffic].project(:oml_ts_server, :wifi_in_bytes, :umts_in_bytes) \
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

def startWebServer(opts)
  port = opts[:port]
  opts[:Logger] ||= MObject.logger('web')
  #opts[:DocumentRoot] ||= NodeHandler.WEB_ROOT()
  #opts[:AccessLog] ||= [[accLog, "%h \"%r\" %s %b"]]
  opts[:TabDir] ||= ['omf-common/web/tab']
  opts[:ResourceDir] ||= ['omf-common/share/htdocs']
  opts[:ViewHelperClass] = ViewHelper
  opts[:StartServerThread] = false
  opts[:ShowTabs] = [:graph3]
  
  OMF::Common::Web::start(port, opts) do |s|
    initGraphs(opts)
    
    trap("HUP") do # use 1 instead of "HUP" on Windows
      s.stop 
    end
  end
end

def initResultService(opts)
  url = opts[:serviceURL]
  adaptor = OMF::Common::OML::Arel::HttpServiceAdaptor.new(url) 

  ropts = {:name => opts[:repoName]}
  opts[:repo] = OMF::Common::OML::Arel::Repository.new(ropts, adaptor) 
end

def error(cat, msg)
  puts "ERROR(#{cat}): #{msg}"
end

def parseCommandLine(opts)
  op = OptionParser.new
  op.banner = "\nStart a web server with a tabbed UI\n\n" +
    "Usage: #{$0} [OPTIONS]\n"+
    "\t[OPTIONS] are any of the following:\n\n" 
  
  op.on("-d", "--debug", "Operate in debug mode [#{opts[:debug]}]") { 
    opts[:debug] = true 
  }
  
  op.on("-p", "--port INT", "Port for server to listen on [#{opts[:port]}]") {|p|
    opts[:port] = p.to_i
  }

  op.on("-r", "--repo-name STRING", "Name of repository [#{opts[:repoName]}]") {|p|
    opts[:repoName] = p
  }

  op.on("-s", "--service-url URL", "URL of the result2 AM service [#{opts[:serviceURL]}]") {|u|
    opts[:serviceURL] = u
  }
  # Parse the command line
  op.parse(ARGV)
end


opts = default_opts.dup
parseCommandLine(opts)
initResultService(opts)
startWebServer(opts)
puts "done"
