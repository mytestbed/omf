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
      :stroke_width => {:property => :sett, :scale => 0.02},
      :stroke_color => {:property => :sett, :scale => 1.0 / 400, :color => :green_yellow80_red}
    }
  }
}

$node_loc = {
  'n1' => [rand, rand],
  'n2' => [rand, rand],
  'n3' => [rand, rand],
  'n4' => [rand, rand],
  'n5' => [rand, rand],
  'n6' => [rand, rand],
  'n7' => [rand, rand],
  'n8' => [rand, rand],
  'n9' => [rand, rand]
}

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

def click_mon_link_stats(stream)
  opts = {:name => 'Link State', :schema => [:ts, :link, :sett, :lett, :bitrate] }
  select = [:oml_ts_server, :id, :neighbor_id, :sett_usec, :lett_usec, :bitrate_mbps]
  t = stream.capture_in_table(select, opts) do |ts, from, to, sett, lett, bitrate|
    set_link(from, to, :sett => sett, :lett => lett, :bitrate => bitrate)
    [ts, "l#{from}-#{to}", sett, lett, bitrate]
  end
  init_graph t.name, t, 'line_chart_fc', 
    :mapping => {:group_by => :link, :x_axis => :ts, :y_axis => :sett},
    :schema => t.schema.describe
  t
end

ep = OmlSqlSource.new("#{File.dirname(__FILE__)}/gec12_demo.sq3")
ep.on_new_stream() do |stream|
  case stream.stream_name
  when 'click_mon_link_stats'
    t = click_mon_link_stats(stream)
  else
    MObject.error(:oml, "Don't know what to do with table '#{stream.stream_name}'")
  end
  if t
    #puts "SCHEMA>>> #{t.schema.describe.inspect}"
    init_graph("#{t.name} (T)", t, 'table', :schema => t.schema.describe)
  end
end
ep.run()
