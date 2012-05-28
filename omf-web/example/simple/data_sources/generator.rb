

require 'omf-oml/table'

# Create a table containing 'amplitude' measurements taken at a certain time for two different 
# devices.
#

schema = [[:t, :float], [:device, :string], [:amplitude, :float], [:x, :float], [:y, :float]]
table = OMF::OML::OmlTable.new 'generator', schema, :max_size => 20

require 'omf_web'
OMF::Web.register_datasource table



samples = 30
ctxt = {
  :timeOffset => Time.now.to_i,
  :timeScale => 300, # Measure every 10 minutes
  :radius => 10,
  :fluctuation => 0.1, # max disturbance of sample
  :rad => 2 * Math::PI / samples
}


def measure(i, table, ctxt) 
  t = ctxt[:timeOffset] + ctxt[:timeScale] * i
  angle = i * ctxt[:rad]
  measure_device('Dev1', t, angle, table, ctxt)
  measure_device('Dev2', t, angle + 0.2 * (rand() - 0.5), table, ctxt)  
end

def measure_device(name, t, angle, table, ctxt)
  r = ctxt[:radius] * (1 + (rand() - 0.5) * ctxt[:fluctuation])
  table.add_row [t, name, r, r * Math.sin(angle), r * Math.cos(angle)]
end

samples.times {|i| measure(i, table, ctxt) }

# Keep on measuring
Thread.new do
  begin
    i = samples
    loop do
      sleep 0.5
      measure i, table, ctxt
      i += 1
    end
  rescue Exception => ex
    puts ex
    puts ex.backtrace.join("\n")
  end
end




