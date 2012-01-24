

require 'omf-oml/table'
require 'omf-oml/sql_source'

include OMF::OML

$nw = OmlNetwork.new 
# $lwidgets << init_graph( 'Network', $nw, 'network', {
  # :mapping => {
    # :node => {
      # :radius => {:property => :capacity, :scale => 20, :min => 4},
      # :fill_color => {:property => :capacity, :scale => :green_yellow80_red}
    # },
    # :link => {
      # :stroke_width => {:property => :store_forward, :scale => 5, :min => 3},
      # :stroke_color => {:property => :store_forward, :scale => 1.0 / 1.3, :color => :green_yellow80_red}
    # }
  # },
  # :height => 500
# })

$node_loc = {}
$node_loc['n1'] = [0.3, 0.6]
$node_loc['n2'] = [0.3, 0.4]
$node_loc['n3'] = [0.4, 0.75]
$node_loc['n4'] = [0.5, 0.25]
$node_loc['n5'] = [0.6, 0.75]
$node_loc['n6'] = [0.7, 0.6]
$node_loc['n7'] = [0.7, 0.4]
$node_loc['n101'] = [0.15, 0.5]
$node_loc['n201'] = [0.85, 0.5]

$node_loc_table = OmlTable.new('node_loc', [[:id, :text], [:loc_x, :int], [:loc_y, :int]], :index => :id)
$node_loc_table.add_rows [ ['1', 0.3, 0.6], 
                           ['2', 0.3, 0.4], 
                           ['3', 0.4, 0.75],
                           ['4', 0.5, 0.25],
                           ['5', 0.6, 0.75],
                           ['6', 0.7, 0.6],
                           ['7', 0.7, 0.4],
                           ['101', 0.15, 0.5],
                           ['201', 0.85, 0.5]
                         ]

#10.times do |i|
#  $node_loc["n#{i}"] = [(i % 5) * 0.2 + 0.1, (i / 3) * 0.3 + 0.1 + 0.1 * rand]
#end

def node_def_opts(n)
  loc = $node_loc[n] || [0.9, 0.9]
  {:x => loc[0], :y => loc[1]}
end

def set_link(from, to, opts)
  lname = "l#{from}-#{to}"
  fn = "n#{from}"
  tn = "n#{to}"
  fromNode = $nw.node(fn, node_def_opts(fn))
  toNode = $nw.node(tn, node_def_opts(tn))
  
  link = $nw.link(lname, :from => fromNode, :to => toNode)
  link.update(opts)
  link
end

def set_node(nid, opts)
  name = "n#{nid}"
  node = $nw.node(name, {})
  node.update(opts.merge(node_def_opts(name)))
  #puts "set_node: #{node.inspect}"
  node
end

$node_table = $link_table = nil
  
def click_mon_link_stats(stream)
  opts = {:name => 'Link State', :schema => [:ts, :link_id, :from_id, :to_id, :store_forward, :sett, :lett, :bitrate], :max_size => 200}
  select = [:oml_ts_server, :id, :neighbor_id, :sett_usec, :lett_usec, :bitrate_mbps]
  t = $link_table = stream.capture_in_table(select, opts) do |ts, from, to, sett, lett, bitrate|
#puts "form: #{from}, to:#{to}"
    store_forward = 1.0 * sett / lett
#    set_link(from, to, :store_forward => store_forward, :bitrate => bitrate)
    [ts.to_i, "l#{from}-#{to}", from, to, store_forward, sett, lett, bitrate]
  end
  gopts = {
    :schema => t.schema.describe,
    :mapping => {:group_by => :link_id, :x_axis => :ts, :y_axis => :store_forward},
    :margin => {:left => 80, :bottom => 40},
    :yaxis => {:ticks => 6},
    :stroke_width => 4
  }
  init_graph(t.name, t, 'line_chart', gopts)
  $rwidgets << init_graph(t.name, t, 'line_chart', gopts.merge(
    :height => 200, :width => 300,
    :xaxis => {:ticks => 3},
    :yaxis => {:ticks => 5}    
  ))  

  t
end

#CREATE TABLE "click_mon_packet_stats" (oml_sender_id INTEGER, oml_seq INTEGER, oml_ts_client REAL, oml_ts_server REAL, 
# "mp_index" UNSIGNED INTEGER, "id" TEXT, "in_pkts" BIGINT, "out_pkts" BIGINT, "errors" BIGINT, "dropped" BIGINT, 
# "in_bytes" BIGINT, "out_bytes" BIGINT);

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
      cd[:type] = :KEY
    end
    cd
  end
  schema = tschema
  schema << {:name => :name, :type => 'TEXT'}
  schema << {:name => :loc_x, :type => 'INTEGER'}
  schema << {:name => :loc_y, :type => 'INTEGER'}
  puts "TSCHEMA>>>> #{tschema.inspect}"
  node_id = select.find_index(:id)
  opts = {:name => 'Node State', :schema => schema, :max_size => 200}
  table = $node_table = stream.capture_in_table(select, opts) do |row|
    # nopts = {}
    # tschema.each_with_index do |cd, i|
      # name = cd[:name]
      # nopts[name] = row[i] unless name == :node
    # end
    #puts "TUPLE>>>> #{nopts.inspect}"    
    nid = row[node_id]
    #set_node(nid, nopts)
    #row[node_id] = "n#{nid}"
    row << nid
    loc = $node_loc["n#{nid}"] || [0,0]
    row + loc
  end
  
  gopts = {
    :schema => table.schema,
    :mapping => {:group_by => :node_id, :x_axis => :ts, :y_axis => :in_chunks},
    :schema => table.schema.describe,
    :margin => {:left => 80, :bottom => 40},
    :yaxis => {:ticks => 6},
    :stroke_width => 4    
  }
  init_graph(table.name, table, 'line_chart_fc', gopts)
  $rwidgets << init_graph(table.name, table, 'line_chart', gopts.merge(
    :height => 200, :width => 300,
    :xaxis => {:ticks => 3},
    :yaxis => {:ticks => 5}    
  ))  
  table  
end




#ep = OmlSqlSource.new("#{File.dirname(__FILE__)}/gec12_demo.sq3")
ep = OmlSqlSource.new($db_name, :offset => -500, :check_interval => 1.0)
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

$lwidgets << init_graph( 'Network', 
  {:nodes => $node_table.indexed_by(:id), :links => $link_table.indexed_by(:link_id)}, #, :node_locs => $node_loc_table },
  'network', {
    :mapping => {
      :nodes => {
        :radius => {:property => :curr_stored_chunks, :scale => 20, :min => 10},
        :fill_color => {:property => :error_chunks, :color => :green_yellow80_red},
        :x => {:property => :loc_x}, # :stream => :node_locs},
        :y => {:property => :loc_y} # , :stream => :node_locs}
      },
      :links => {
        :key => {:property => :link_id},
        :stroke_width => {:property => :store_forward, :scale => 5, :min => 3},
        :stroke_color => {:property => :store_forward, :scale => 1.0 / 1.3, :color => :green_yellow80_red},
        # :from => {:key => :from_id, :join_stream => :node_locs},               
        # :to => {:key => :to_id, :join_stream => :node_locs}
        :from => {:key => :from_id, :join_stream => :nodes},               
        :to => {:key => :to_id, :join_stream => :nodes}
      }
    },
    :schema => {
      :nodes => $node_table.schema,
      :links => $link_table.schema,
      :node_locs => $node_loc_table.schema
    },
    :height => 500
  }
)



