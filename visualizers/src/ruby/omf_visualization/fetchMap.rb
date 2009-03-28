require 'net/http'
require 'graphml'
require 'rexml/document'
include REXML


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
  ml.add_schema 'strength', 'edge', 'strength', 'integer', 10

  missing = []
  edges = []
  d = Document.new r.body
  d.elements.each("DATABASE/RESULT/ROW") do |e| 
    left, right, strength = e.text.split
    left_id = Inventory.mac_to_node_id(left)
    missing << left unless left_id

    right_id = Inventory.mac_to_node_id(right)
    missing << right unless right_id

    if right_id && left_id && strength.to_i < 0  # sanity check on DB
      edges << [left_id, right_id, strength]
      #puts "#{left_id} => #{right_id} : #{strength}"
    end
  end
  # sort by signal strength to draw weak nodes first
  edges.sort do |x,y| 
    y[2] <=> x[2]
  end.each do |left_id, right_id, strength|
    ml.add_edge left_id, right_id, :strength => strength
  end
  #puts missing.uniq
  ml
end


require 'webrick'

def start_web_server(db_name, port = 2000)
  s = WEBrick::GenericServer.new( :Port => port )
  trap("INT"){ s.shutdown }
  s.start{|sock|
    ml = run(db_name)
    ml.write sock
  }
end

require 'optparse'

opts = OptionParser.new
opts.banner = "Simple web server \n\n" +
                "Usage: #{ARGV} experiment_id\n"

opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }

db_name = opts.parse(ARGV)[0]

start_web_server db_name







