

require 'digest/md5'
require 'omf-common/web2/tabbed_server'
require 'omf-common/web2/tab/graph/graphService'
include OMF::Common::Web2

$TITLE = "Smart Caching Demo"


$DEF_OPTS = {
  :debug => false,
  :port => 4040,
  :serviceURL => 'http://localhost:5053/result2/query',
  :serviceURL => 'http://srv.mytestbed.net:5053/result2/query',  
  :repoName => 'prefetching_4',
  # Starting time for most graphs
#  :startTime => 2e6
}


def testTable(repo)
  opts = {
    :type => :series,
    :prefix => "The following table shows the recently requested content",
    :postfix => "The table above shows the recently requested content",    
    :visOpts => {
      :labels => ["Time", "Name", "URL", "Status"]
    }
  }
  Graph.addGraph('TABLE', 'table', opts) do |g|
    [
      :data => [[0, 'Movie1', 'url1', 'ok'],
                  [1, 'Movie2', 'url2', 'missing']]
    ]
  end
end

def testSeries(repo)
  opts = {
    :type => :series,
    :visOpts => {
    }
  }
  count = -2
  Graph.addGraph('CHART', 'line_chart', opts) do |g|
    count += 2
    [
      {:label => 'line1', :data => [[count, count], [count + 1, count + 1]]},
      {:label => 'line2', :data => [[count, count + 1], [count + 1, count + 2]]}
    ]
  end
end

def content(repo)
  opts = {
    :type => :series,
    :updateEvery => 3,
    :prefix => "The following table shows the recently requested content",
    :postfix => "The table above shows the recently requested content",    
    :visOpts => {
      :labels => ["Time", "Name", "URL", "Status"]
    }
  }
  Graph.addGraph('Content', 'table', opts) do |g|
    s = []
    repo[:mediacontent].project(:oml_ts_server, :name, :url, :status) do |r|
      ts, name, url, status = r.tuple
      ourl = url
      if (url.length > 23)
        url = url.slice(0..9) + '...' + url.slice(-10 .. -1)
      end
      #md5 = Digest::MD5.hexdigest(url)
      #s << [md5, ts.to_int, name, "<a href='#{ourl}'>#{url}</a>", status]
      s << [ts.to_int, name, "<a href='#{ourl}'>#{url}</a>", status]
    end
    s
  end
end

def downloads(repo)
  opts = {
    :type => :series,
    :updateEvery => 3,    
    :visOpts => {
      :xLabel => "Time [sec]",      
      :yLabel =>  "Received Traffic [Kbytes]",
      :yMin => 0
    }
  }
  Graph.addGraph('Download', 'line_chart', opts) do |g|
    wifi = []
    umts = []
    #repo[:traffic].project(:oml_ts_server, :wifi_in_bytes, :umts_in_bytes) \
        #.where(repo[:traffic][:oml_ts_server].gt(startTime)).each do |r|
    repo[:traffic].project(:oml_ts_server, :wifi_in_bytes, :umts_in_bytes).each do |r|
      ts, w, u = r.tuple
      wifi << [ts, w]
      umts << [ts, u]
    end
    [{:label => "WiFi", :data => wifi},
     {:label => "UMTS", :data => umts}]
  end
end



# OMF::Common::Web2::Graph.addGraph('Graph X', 'line_chart') do |g|
  # g.addSeries([[1,1], [3,3]])
# end
# 

def initResultService(opts)
  url = opts[:serviceURL]
  adaptor = OMF::Common::OML::Arel::HttpServiceAdaptor.new(url) 

  ropts = {:name => opts[:repoName]}
  opts[:repo] = OMF::Common::OML::Arel::Repository.new(ropts, adaptor) 
end


def parseCommandLine(opts)
  require 'optparse'
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


opts = $DEF_OPTS.dup
parseCommandLine(opts)
initResultService(opts)

testTable(nil)
testSeries(nil)
content(opts[:repo])
downloads(opts[:repo])

OMF::Common::Web2.start(:page_title => $TITLE, :port => opts[:port])
