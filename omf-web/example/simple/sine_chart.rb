

require 'omf-oml/table'

# Create a table containing 'amplitude' measurements taken at a certain time for two different 
# devices.
#
samples = 20
timeOffset = Time.now.to_i
timeScale = 600

schema = [[:t, :float], [:device, :string], [:amplitude, :float]]
table = OMF::OML::OmlTable.new 'amplitude', schema, :max_size => 30
rad = 2 * Math::PI / samples
samples.times do |i|
  t = timeOffset + timeScale * i
  table.add_row [t, 'Sin', Math.sin(i * rad)]
  table.add_row [t, 'Cos', Math.cos(i * rad)]
end

# Move mobile node
Thread.new do
  begin
    i = samples
    loop do
      sleep 0.5
      t = timeOffset + timeScale * i
      table.add_row [t, 'Sin', Math.sin(i * rad)]
      table.add_row [t, 'Cos', Math.cos(i * rad)]
      i += 1
    end
  rescue Exception => ex
    puts ex
    puts ex.backtrace.join("\n")
  end
end

# Register a graph widget to visualize the table as a line chart
#
opts = {
  #:data_sources => table,
  #:viz_type => 'line_chart',
  :wtype => 'graph',
  :dynamic => {:updateInterval => 1},
  :wopts => {
    :viz_type => 'line_chart2',
    :data_sources => table,
    :dynamic => true,
    :mapping => { :x_axis => :t, :y_axis => :amplitude, :group_by => :device },
    :axis => {
      :x => {
        :ticks => {
          :type => :date,
          :format => '%I:%M'
        },
        :legend => 'Time (sec)'
      },
      :y => {
        :legend => 'Amplitude'
      }
    }
  }
  
}
OMF::Web::Widget::Graph.addGraph('Amplitude', opts)

opts = {
  :wtype => 'graph',
  :dynamic => {:updateInterval => 1},
  :wopts => {
    :viz_type => 'table',
    :data_sources => table,
    :dynamic => true,
  }
  
}
OMF::Web::Widget::Graph.addGraph('Amplitude (T)', opts)  
#OMF::Web::Widget.register('Amplitude', opts) 



