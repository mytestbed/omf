

# CREATE TABLE _experiment_metadata (key TEXT PRIMARY KEY, value TEXT);
# CREATE TABLE _senders (name TEXT PRIMARY KEY, id INTEGER UNIQUE);
# CREATE TABLE "oml2_nmetrics_cpu" (oml_sender_id INTEGER, oml_seq INTEGER, oml_ts_client REAL, oml_ts_server REAL, "user" BLOB, "sys" BLOB, "nice" BLOB, "idle" BLOB, "wait" BLOB, "irq" BLOB, "soft_irq" BLOB, "stolen" BLOB, "total" BLOB);
# CREATE TABLE "oml2_nmetrics_memory" (oml_sender_id INTEGER, oml_seq INTEGER, oml_ts_client REAL, oml_ts_server REAL, "ram" BLOB, "total" BLOB, "used" BLOB, "free" BLOB, "actual_used" BLOB, "actual_free" BLOB);
# CREATE TABLE "oml2_nmetrics_net_if" (oml_sender_id INTEGER, oml_seq INTEGER, oml_ts_client REAL, oml_ts_server REAL, "name" TEXT, "rx_packets" BLOB, "rx_bytes" BLOB, "rx_errors" BLOB, "rx_dropped" BLOB, "rx_overruns" BLOB, "rx_frame" BLOB, "tx_packets" BLOB, "tx_bytes" BLOB, "tx_errors" BLOB, "tx_dropped" BLOB, "tx_overruns" BLOB, "tx_collisions" BLOB, "tx_carrier" BLOB, "speed" BLOB);

# CREATE TABLE "oml2_nmetrics_cpu" (oml_sender_id INTEGER, oml_seq INTEGER, oml_ts_client REAL, oml_ts_server REAL, "user" BLOB, "sys" BLOB, "nice" BLOB, "idle" BLOB, "wait" BLOB, "irq" BLOB, "soft_irq" BLOB, "stolen" BLOB, "total" BLOB);
def oml2_nmetrics_cpu(stream)
  opts = {:name => 'CPU', :schema => [:ts, :client_id, :user, :sys, :nice, :idle, :wait], :max_size => 200}
  select = [:oml_ts_server, :oml_sender_id, :user, :sys, :nice, :idle, :wait, :total]
  tss = {}
  t = stream.capture_in_table(select, opts) do |ts, cid, user, sys, nice, idle, wait, total|
    user = user.u64; sys = sys.u64; nice = nice.u64; idle = idle.u64; wait = wait.u64; total = total.u64
    last = tss[cid]
    tss[cid] = [user, sys, nice, idle, wait, total]
    if last
      l_user, l_sys, l_nice, l_idle, l_wait, l_total = last
      f = 1.0 * (total - l_total)
      [ts, cid, (user - l_user) / f, (sys - l_sys) / f, (nice - l_nice) / f, (idle - l_idle) / f, (wait - l_wait) / f]      
    else
      nil
    end
  end
  gopts = {
    :schema => t.schema,
    :mapping => {
      :x_axis => {:property => :ts},
      :y_axis => {:property => :user},
      :group_by => {:property => :client_id},
      :stroke_width => 4    
    },
    :margin => {:left => 80, :bottom => 40},
    :yaxis => {:ticks => 6, :min => 0},
    :ymin => 0
  }
  init_graph(t.name, t, 'line_chart', gopts)
  t
end

# CREATE TABLE "oml2_nmetrics_memory" (oml_sender_id INTEGER, oml_seq INTEGER, oml_ts_client REAL, oml_ts_server REAL, "ram" BLOB, "total" BLOB, "used" BLOB, "free" BLOB, "actual_used" BLOB, "actual_free" BLOB);
def oml2_nmetrics_memory(stream)
  opts = {:name => 'Memory', :schema => [:ts, :client_id, :ram, :total, :used, :free, :actual_used, :actual_free], :max_size => 200}
  select = [:oml_ts_server, :oml_sender_id, :ram, :total, :used, :free, :actual_used, :actual_free]
  t = stream.capture_in_table(select, opts) do |ts, cid, ram, total, used, free, actual_used, actual_free|
    [ts, cid, ram.u64, total.u64 / 1e6, used.u64 / 1e6, free.u64 / 1e6, actual_used.u64 / 1e6, actual_free.u64 / 1e6]
  end
  gopts = {
    :schema => t.schema,
    :mapping => {
      :x_axis => {:property => :ts},
      :y_axis => {:property => :actual_free},
      :group_by => {:property => :client_id},
      :stroke_width => 4    
    },
    :margin => {:left => 80, :bottom => 40},
    :yaxis => {:ticks => 6, :min => 0},
    :ymin => 0
  }
  init_graph(t.name, t, 'line_chart', gopts)
  t
end








