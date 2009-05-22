require 'net/http'
require 'stringio'
require 'webrick'
require 'webrick/httputils'
require 'graphml'
require 'rexml/document'

include REXML
include OMF::Visualization

QUERY = %{
  SELECT t.myMacAddress, t.macAddress, t.DBM
  FROM wlanconfig_oml2_wifi_info AS t, 
    (SELECT myMacAddress, macAddress, MAX(oml_ts_server) AS ts
     FROM wlanconfig_oml2_wifi_info
     GROUP BY myMacAddress, macAddress) AS q
  WHERE t.oml_ts_server = q.ts AND t.myMacAddress = q.myMacAddress AND t.macAddress = q.macAddress
}

def run(db_name)
  url = "http://norbit.npc.nicta.com.au:5022/result/queryDatabase?expID=#{db_name}&query=#{URI.escape(QUERY)}"
  r = Net::HTTP::get_response(URI.parse(url))

  ml = GraphML.create_tb_map
  ml.add_schema 'strength', 'edge', :type => 'integer', :default => 10

  missing = []  # collect nodes mssing from inventory
  edges = []
  d = Document.new r.body
  d.elements.each("DATABASE/RESULT/ROW") do |e| 
# puts e.text
    left, right, strength_s = e.text.split
    strength = strength_s.to_i

 #   strength = -20 if strength == 0 ##HACK

    left_id = Inventory.mac_to_node_id(left)
    missing << left unless left_id

    right_id = Inventory.mac_to_node_id(right)
    missing << right unless right_id

    if right_id && left_id && strength < 0  # sanity check on DB
      if right_id != left_id
        edges << [left_id, right_id, strength]
        puts "edge: #{left_id} => #{right_id} : #{strength}"
      end
    else
#      puts "Unknown edge: #{right_id.class} #{right} #{left_id.class} #{strength} : #{e}"
    end
  end
  # sort by signal strength to draw weak nodes first
  edges.sort do |x,y| 
#    y[2] <=> x[2]
    x[2] <=> y[2]
  end.each do |left_id, right_id, strength|
    ml.add_edge left_id, right_id, :strength => strength
  end

  puts "Unknown nodes in result:"
  puts missing.uniq

  ml
end


require 'webrick'

def start_web_server(db_name, port = 2000)
  s = WEBrick::HTTPServer.new( :Port => port )
  trap("INT"){ s.shutdown }


  s.mount_proc('/graph') do |req, resp|
    ml = run(db_name)
    si = StringIO.new
    ml.write si
    resp.body = si.string
    resp['content-type'] = 'text/xml'
  end

  s.mount_proc('/crossdomain.xml') do |req, res|
    res.body = %{
<cross-domain-policy>
    <allow-access-from domain="*"/>
</cross-domain-policy>
}
    res['content-type'] = 'text/xml'
  end    

  s.start
end

require 'optparse'

opts = OptionParser.new
opts.banner = "\nSimple web server to provide a coverage map \n\n" +
                "Usage: #{$0} experiment_id\n"

opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }

db_name = opts.parse(ARGV)[0]
if db_name.nil?
	puts opts
	exit -1
end

start_web_server db_name







