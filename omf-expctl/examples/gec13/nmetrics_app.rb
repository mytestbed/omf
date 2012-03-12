defApplication('nmetrics_app', 'nmetrics') do |a|

  a.version(2, 5)
  a.path = "/usr/bin/oml2-nmetrics"
  a.shortDescription = 'Monitoring node statistcs'
  a.description = %{
'nmetrics' is monitoring various node specific statistics,
such as CPU, memory and network usage and reports them through
OML. }

  a.defProperty('cpu', 'Report cpu usage', 
                '-c', {:type => :boolean, :dynamic => false})
  a.defProperty('interface',
                'Report network interface usage (can be used multiple times)',
                '-i', {:type => :string, :dynamic => false})
  a.defProperty('memory', 'Report memory usage', 
                '-m', {:type => :boolean, :dynamic => false})
  a.defProperty('sample-interval',
                'Time between consecutive measurements [sec], default 1s', 
                '-s', {:type => :integer, :dynamic => false})

  a.defMeasurement("memory") do |m|
    m.defMetric('ram', :long)
    m.defMetric('total', :long)
    m.defMetric('used', :long)
    m.defMetric('free', :long)
    m.defMetric('actual_used', :long)
    m.defMetric('actual_free', :long)
  end

  a.defMeasurement("cpu") do |m|
    m.defMetric('user', :long)
    m.defMetric('sys', :long)
    m.defMetric('nice', :long)
    m.defMetric('idle', :long)
    m.defMetric('wait', :long)
    m.defMetric('irq', :long)
    m.defMetric('soft_irq', :long)
    m.defMetric('stolen', :long)
    m.defMetric('total', :long)
  end

  a.defMeasurement("net_if") do |m|
    m.defMetric('name', :string)
    m.defMetric('rx_packets', :long)
    m.defMetric('rx_bytes', :long)
    m.defMetric('rx_errors', :long)
    m.defMetric('rx_dropped', :long)
    m.defMetric('rx_overruns', :long)
    m.defMetric('rx_frame', :long)
    m.defMetric('tx_packets', :long)
    m.defMetric('tx_bytes', :long)
    m.defMetric('tx_errors', :long)
    m.defMetric('tx_dropped', :long)
    m.defMetric('tx_overruns', :long)
    m.defMetric('tx_collisions', :long)
    m.defMetric('tx_carrier', :long)
    m.defMetric('speed', :long)
  end

  a.defMeasurement("procs") do |m|
    m.defMetric('cpu_id', :long)
    m.defMetric('total', :long)
    m.defMetric('sleeping', :long)
    m.defMetric('running', :long)
    m.defMetric('zombie', :long)
    m.defMetric('stopped', :long)
    m.defMetric('idle', :long)
    m.defMetric('threads', :long)
  end

  a.defMeasurement("proc") do |m|
    m.defMetric('pid', :long)
    m.defMetric('start_time', :long)
    m.defMetric('user', :long)
    m.defMetric('sys', :long)
    m.defMetric('total', :long)
  end

end

# Local Variables:
# mode:ruby
# End:
