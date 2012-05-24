

require 'omf-oml/table'

# Create a table containing 'amplitude' measurements taken at a certain time for two different 
# devices.
#

schema = [[:t, :float], [:device, :string], [:amplitude, :float]]
table = OMF::OML::OmlTable.new 'generator', schema, :max_size => 60

require 'omf_web'
OMF::Web.register_datasource table



samples = 30
ctxt = {
  :timeOffset => Time.now.to_i,
  :timeScale => 300, # Measure every 10 minutes
  :fluctuation => 0.1, # max disturbance of sample
  :rad => 2 * Math::PI / samples
}


def measure(i, table, ctxt) 
  t = ctxt[:timeOffset] + ctxt[:timeScale] * i
  table.add_row [t, 'Sin', Math.sin(i * ctxt[:rad]) + rand() * ctxt[:fluctuation]]
  table.add_row [t, 'Cos', Math.cos(i * ctxt[:rad]) + rand() * ctxt[:fluctuation]]
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




