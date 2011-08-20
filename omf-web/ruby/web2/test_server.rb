

require 'omf-common/web2/tabbed_server'

# Define data sources
#

# This one creates a data stream internally
require 'omf-common/web2/tab/graph/oml_table'
t1 = OMF::Common::OML::OmlTable.new('s1', [[:x], [:y]], :max_size => 20)
Thread.new do
  i = 0
  while true
    begin
      i = i + 1 
      t1.add_row [i, rand]
      #puts t1.rows.join(' ')
      sleep 1
    rescue Exception => ex
      puts "ERROR: #{ex}"
    end
  end
end

# This defines an OML endpoint. It expects a stream from the 
# OML example generator on port 3000.
#
# % ./oml_example --oml-config config_text_stream.xml
#
require 'omf-common/web2/tab/graph/oml_endpoint'
ep = OMF::Common::OML::OmlEndpoint.new(3000)
toml = OMF::Common::OML::OmlTable.new('oml', [[:x], [:y]], :max_size => 20)
ep.on_new_stream() do |s|
  puts "New stream: #{s}"
  s.on_new_vector() do |v|
    #puts "New vector: #{v.to_a(true).join('|')}"      
    toml.add_row(v.select(:oml_ts, :value))
  end
end
ep.run()  # Start the endpoint

#
# Configure two graph displays
#
require 'omf-common/web2/tab/graph/graph_service'
i = 0
gopts = {
  :data_source => t1,
  :default_label => 'randomst',  
  :viz_type => 'line_chart',
  :viz_opts => {},
  :dynamic => true # push data to browser
}
OMF::Common::Web2::Graph.addGraph('Internal', gopts) do |g, rows|
  #puts "HIHHH #{rows.inspect}"
  data = rows.collect do |r|
    [r[:x], r[:y]]
  end
  [{:label => "AAA", :data => data}]
end

gopts2 = {
  #:query => ms[:foo]....
  :data_source => toml,
  :default_label => 'sin',
  :viz_type => 'line_chart',
  :viz_opts => {},
  :dynamic => true 
}
OMF::Common::Web2::Graph.addGraph('OML', gopts2) do |g, rows|
  puts "HIHHH #{rows.inspect}"
  data = rows.collect do |r|
    [r[:oml_ts], r[:value]]
  end
  [{:label => "AAA", :data => data}]
end

# Configure the web server
#
opts = {
  :sslNOT => {
    :cert_chain_file => "#{File.dirname(__FILE__)}/debug/server_chain.crt", 
    :private_key_file => "#{File.dirname(__FILE__)}/debug/server.key", 
    :verify_peer => false
  },
  
  # :tabs => {
    # :foo => {:name => 'Foo', :order => 1, :class => Foo},
    # :goo => {:name => 'Goo', :order => 3}
  # }
}
OMF::Common::Web2.start(opts)
