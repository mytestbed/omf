

require 'omf-oml/table'
require 'omf-oml/sql_source'

include OMF::OML

$nw = OmlNetwork.new 
init_graph 'Network', $nw, 'network', {
  :mapping => {
    :node => {
      :radius => {:property => :capacity, :scale => 20, :min => 4},
      :fill_color => {:property => :capacity, :scale => :green_yellow80_red}
    },
    :link => {
      :stroke_width => {:property => :sett, :scale => 0.03, :min => 3},
      :stroke_color => {:property => :sett, :scale => 1.0 / 400, :color => :green_yellow80_red}
    }
  }
}

$node_loc = {}
10.times do |i|
  $node_loc["n#{i}"] = [(i % 5) * 0.2 + 0.1, (i / 3) * 0.3 + 0.1 + 0.1 * rand]
end

def set_link(from, to, opts)
  lname = "l#{from}-#{to}"
  fn = "n#{from}"
  tn = "n#{to}"
  fromNode = $nw.node(from, :x => $node_loc[fn][0], :y => $node_loc[fn][1])
  toNode = $nw.node(to, :x => $node_loc[tn][0], :y => $node_loc[tn][1])
  
  link = $nw.link(lname, :from => fromNode, :to => toNode)
  link.update(opts)
  link
end

def set_node(nid, opts)
  name = "n#{nid}"
  node = $nw.node(name, {})
  node.update(opts)
  node
end

def click_mon_link_stats(stream)
  opts = {:name => 'Link State', :schema => [:ts, :link, :sett, :lett, :bitrate] }
  select = [:oml_ts_server, :id, :neighbor_id, :sett_usec, :lett_usec, :bitrate_mbps]
  t = stream.capture_in_table(select, opts) do |ts, from, to, sett, lett, bitrate|
    set_link(from, to, :sett => sett, :lett => lett, :bitrate => bitrate)
    [ts, "l#{from}-#{to}", sett, lett, bitrate]
  end
  init_graph t.name, t, 'line_chart', 
    :mapping => {:group_by => :link, :x_axis => :ts, :y_axis => :sett},
    :schema => t.schema.describe,
    :margin => {:left => 80, :bottom => 40},
    :yaxis => {:ticks => 6},
    :stroke_width => 4
  t
end

#CREATE TABLE "click_mon_packet_stats" (oml_sender_id INTEGER, oml_seq INTEGER, oml_ts_client REAL, oml_ts_server REAL, "mp_index" UNSIGNED INTEGER, "id" TEXT, "in_pkts" BIGINT, "out_pkts" BIGINT, "errors" BIGINT, "dropped" BIGINT, "in_bytes" BIGINT, "out_bytes" BIGINT);

def click_mon_routing_stats(stream)
  sschema = stream.schema.columns.select do |cd|
    ! [:oml_sender_id, :oml_seq, :oml_ts_client, :mp_index].include?(cd[:name])
  end
  select = sschema.collect do |cd| cd[:name] end
  tschema = sschema.collect do |cd|
    case cd[:name]
    when :oml_ts_server
      cd[:name] = :ts
    when :id
      cd[:name] = :node
    end
    cd
  end
  #puts "TSCHEMA>>>> #{tschema.inspect}"
  node_id = select.find_index(:id)
  opts = {:name => 'Node State', :schema => tschema}
  table = stream.capture_in_table(select, opts) do |row|
    nopts = {}
    tschema.each_with_index do |cd, i|
      name = cd[:name]
      nopts[name] = row[i] unless name == :node
    end
    #puts "TUPLE>>>> #{nopts.inspect}"    
    nid = row[node_id]
    set_node(nid, nopts)
    row[node_id] = "n#{nid}"
    row
  end
  
  init_graph table.name, table, 'line_chart', 
    :mapping => {:group_by => :node, :x_axis => :ts, :y_axis => :curr_stored_chunks},
    :schema => table.schema.describe,
    :margin => {:left => 80, :bottom => 40},
    :yaxis => {:ticks => 6},
    :stroke_width => 4    
  table  
end

ep = OmlSqlSource.new("#{File.dirname(__FILE__)}/gec12_demo.sq3")
ep.on_new_stream() do |stream|
  case stream.stream_name
  when 'click_mon_link_stats'
    t = click_mon_link_stats(stream)
  when 'click_mon_routing_stats'
    t = click_mon_routing_stats(stream)
  else
    MObject.error(:oml, "Don't know what to do with table '#{stream.stream_name}'")
  end
  if t
    #puts "SCHEMA>>> #{t.schema.describe.inspect}"
    init_graph("#{t.name} (T)", t, 'table', :schema => t.schema.describe)
  end
end
ep.run()



