
# CREATE TABLE _experiment_metadata (key TEXT PRIMARY KEY, value TEXT);
# CREATE TABLE _senders (name TEXT PRIMARY KEY, id INTEGER UNIQUE);
# CREATE TABLE "iperf_connection" (oml_sender_id INTEGER, oml_seq INTEGER, oml_ts_client REAL, oml_ts_server REAL, "pid" INTEGER, "connection_id" INTEGER, "local_address" TEXT, "local_port" INTEGER, "foreign_address" TEXT, "foreign_port" INTEGER);
# CREATE TABLE "iperf_losses" (oml_sender_id INTEGER, oml_seq INTEGER, oml_ts_client REAL, oml_ts_server REAL, "pid" INTEGER, "connection_id" INTEGER, "begin_interval" REAL, "end_interval" REAL, "total_datagrams" INTEGER, "lost_datagrams" INTEGER);
# CREATE TABLE "iperf_transfer" (oml_sender_id INTEGER, oml_seq INTEGER, oml_ts_client REAL, oml_ts_server REAL, "pid" INTEGER, "connection_id" INTEGER, "begin_interval" REAL, "end_interval" REAL, "size" INTEGER);

def iperf_transfer(stream)
  # "pid" INTEGER, "connection_id" INTEGER, "begin_interval" REAL, "end_interval" REAL, "size" INTEGER);
  opts = {:name => 'Transfer', :schema => [:ts, :server, :cid, :size, :sender], :max_size => 200}
  select = [:oml_ts_client, :oml_sender, :connection_id, :size, :foreign_address]
  tss = {}
  t = stream.capture_in_table(select, opts)
  gopts = {
    :schema => t.schema,
    :mapping => {
      :x_axis => {:property => :ts},
      :y_axis => {:property => :size},
      :group_by => {:property => :cid},
      :stroke_width => 4    
    },
    :margin => {:left => 80, :bottom => 40},
    :yaxis => {:ticks => 6, :min => 0},
    :ymin => 0
  }
  init_graph(t.name, t, 'line_chart', gopts)
  t
end

def iperf_losses(stream)
  # "pid" INTEGER, "connection_id" INTEGER, "begin_interval" REAL, "end_interval" REAL, "total_datagrams" INTEGER, "lost_datagrams" INTEGER);
  opts = {:name => 'Losses', :schema => [:ts, :server, :cid, :loss_ratio], :max_size => 200}
  select = [:oml_ts_client, :oml_sender, :connection_id, :total_datagrams, :lost_datagrams]
  tss = {}
  t = stream.capture_in_table(select, opts) do |ts, server, cid, total, lost|
    [ts, server, cid, 1.0 * lost / total]
  end
  gopts = {
    :schema => t.schema,
    :mapping => {
      :x_axis => {:property => :ts},
      :y_axis => {:property => :loss_ratio},
      :group_by => {:property => :cid},
      :stroke_width => 4    
    },
    :margin => {:left => 80, :bottom => 40},
    :yaxis => {:ticks => 6, :min => 0},
    :ymin => 0
  }
  init_graph(t.name, t, 'line_chart', gopts)
  t
end


OMF::Web::Widget::Graph.addGraph 'Overview', :viz_type => 'demo_topo', :data_sources => [] 
