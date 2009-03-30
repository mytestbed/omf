#
# Start a webrick server which serves:
#
#   /graph => a GraphML file
#
require 'rexml/document'
include REXML

Positions = {
  "1" => [50, 150],
  "2" => [150, 140],
  "3" => [250, 160],
  "4" => [450, 150],
  "5" => [350, 150],
  "6" => [100, 280],
  "7" => [350, 280 ],
  "8" => [50, 410],
  "9" => [130, 400],
  "10" => [ 250, 420],
  "11" => [ 350, 410],
  "12" => [ 200, 510],
  "13" => [ 350, 510]
}

Quality = [
  [0.00, 27.83, 28.27, 17.84, 0.00, 36.36, 9.89, 9.11, 11.08, 15.44, 7.58, 17.43, 8.58, 0.00],
  [27.90, 0.00, 36.72, 14.99, 0.00, 28.34, 14.14, 0.00, 0.00, 12.19, 11.74, 0.00, 0.00, 0.00],
  [24.28, 29.60, 0.00, 25.56, 46.61, 22.33, 19.45, 5.85, 9.27, 23.05, 18.05, 26.59, 15.64, 0.00],
  [13.44, 14.59, 25.53, 0.00, 30.42, 10.80, 17.53, 0.00, 0.00, 12.03, 15.61, 8.25, 9.52, 0.00],
  [0.00, 0.00, 49.50, 28.59, 0.00, 18.42, 32.77, 0.00, 4.10, 22.98, 22.72, 18.73, 15.51, 0.00],
  [28.15, 17.79, 20.69, 10.50, 15.49, 0.00, 17.43, 12.14, 19.57, 23.31, 17.06, 24.56, 13.09, 0.00],
  [9.41, 13.66, 24.94, 18.55, 38.90, 21.01, 0.00, 0.00, 8.49, 23.78, 27.55, 22.84, 20.93, 0.00],
  [8.39, 0.00, 6.46, 0.00, 0.00, 14.20, 0.00, 0.00, 11.05, 15.28, 10.77, 9.11, 6.46, 0.00],
  [8.07, 0.00, 7.68, 0.00, 4.11, 18.33, 7.25, 9.17, 0.00, 18.41, 14.66, 26.63, 13.21, 0.00],
  [14.00, 12.14, 26.48, 13.81, 24.28, 24.34, 16.55, 15.62, 17.55, 0.00, 37.86, 40.98, 32.33, 0.00],
  [7.69, 11.87, 24.71, 17.36, 27.79, 16.22, 27.39, 10.77, 17.57, 48.65, 0.00, 41.23, 29.24, 0.00],
  [14.46, 0.00, 24.38, 9.47, 16.78, 24.18, 24.26, 8.17, 23.11, 40.25, 31.80, 0.00, 27.89, 0.00],
  [8.02, 0.00, 19.50, 10.28, 18.07, 14.75, 20.12, 5.43, 14.51, 38.47, 26.93, 32.41, 0.00, 0.00]
]

require  'omf_visualization/graphml'

def send_graph(sock)
  
  ml = OMF::Visualization::GraphML.new
  ml.add_schema 'name', 'node'
  ml.add_schema 'x', 'node', 'x', 'integer', 100
  ml.add_schema 'y', 'node', 'y', 'integer', 100
  ml.add_schema 'strength', 'edge', 'strength', 'integer', 10
  
  # just to keep the current flash program happy
  ml.add_schema 'gender', 'node', 'gender', 'string', 'X'
  
  #ml.add_node "1", :name => 'foo'
  
  Positions.each do |id, pos|
    attr = {:x => pos[0], :y => pos[1]}
    ml.add_node id, attr
  end
  
  edges = []
  (1 .. Quality.length).each do |n|
    row = Quality[n -1]
    (1 .. n - 1).each do |o|
      q = row[o - 1]
      edges << [o, n, q.to_i]
    end
  end
  edges.sort do |a, b| a[2] <=> b[2] end.each do |from, to, strength|
    ml.add_edge from, to, :strength => strength
  end
  ml.write(sock)
end

require 'webrick'
require 'uri'
require 'stringio'

def start_web_server(port = 2000)
  s = WEBrick::HTTPServer.new(:Port => port)
  trap("INT") do s.shutdown end
  s.mount_proc('/graph') do |req, resp|
    ss = StringIO.new()
    send_graph ss
    resp.body = ss.string
  end
  
  s.mount_proc('/crossdomain.xml') do |req, resp|
    resp.body = %{
<cross-domain-policy>
    <allow-access-from domain="*"/>
</cross-domain-policy>
    }
    resp['content-type'] = 'text/xml'
  end
  
  s.mount_proc('/graphConfig') do |req, resp|
    resp.body = %{
{"omf_vis": {
  "type": "timeline",
  "data" : {
    "type": "tab",
    "url": "http://localhost:2000/timeline"
  },
  "config": {
    "axis": {
      "x": {"field": "date", "flush": true},
      "y": {"field" : "count"}
    },
    "encoders": [
      {"type": "color", 
        "source": "series", "group": "nodes", 
        "target" : "fillColor", "scaleType" : "categories"},
      {"type": "color", 
        "source": "series", "group": "edges", 
        "target" : "lineColor", "scaleType" : "categories"},
      {"type": "property", 
        "lineAlpha": 0, "alpha": 0.5, "buttonMode": false,
        "scaleX": 1, "scaleY": 1, "size": 0.5},
      {"type": "property", "group": "edges",
        "lineWidth": 1}
    ]
  }
}}
    }
    
    url = "file:/Users/max/src/prefuse.flare-alpha-20080808/homicides.tab.txt"
    format = "tab"
    
    expID = "outdoor_2009_03_27_18_33_57"
    q = "select seq_no, oml_ts_client from otr2_udp_in;"
    url = "http://console.outdoor.orbit-lab.org:5012/result/queryDatabase?expID=#{expID}&query=#{q}&format=json"
    format = "json"
    
    resp.body = %{
{"omf_vis": {
  "type": "timeline",
  "data" : {
    "format": "#{format}",
    "url": "#{URI.escape(url)}"
  },
  "config": { 
    "axis": {
      "x": {"field": "oml_ts_client", "flush": false},
      "y": {"field" : "seq_no"}
    },
    "encoders": [
      {"type": "color", 
        "source": "cause", "group": "nodes", 
        "target" : "fillColor", "scaleType" : "categories"},
      {"type": "color", 
        "source": "series", "group": "edges", 
        "target" : "lineColor", "scaleType" : "categories"},
      {"type": "property", 
        "lineAlpha": 0, "alpha": 0.5, "buttonMode": false,
        "scaleX": 1, "scaleY": 1, "size": 0.5},
      {"type": "property", "group": "edges",
        "lineWidth": 1}
    ]
  }
}}
    }

    resp['content-type'] = 'text/json'
  end  
    
  s.start
end

#require 'net/http'
require 'optparse'

port = 2000

opts = OptionParser.new
opts.banner = "Web server for testing visualization componentsr \n\n" +
                "Usage: #{ARGV} experiment_id\n"
opts.on_tail("-h", "--help", "Show this message") do puts opts; exit end
opts.on_tail("-p", "--port PORT_NO", "Port to listen on [#{port}]") do |p|
  port = p.to_i
end


db_name = opts.parse(ARGV)[0]

start_web_server port




