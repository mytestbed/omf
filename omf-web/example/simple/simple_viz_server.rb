
require 'omf-common/mobject2'
OMF::Common::Loggable.init_log 'demo'


require 'omf-oml/table'
require 'omf-web/widget/code/code'
require 'omf-web/widget/graph/graph'

['sine_chart.rb', 'pie_chart.rb', 'dynamic_network.rb', 'network.rb', 'map.rb'].each do |f|
  load "#{File.dirname(__FILE__)}/#{f}"
end

# Configure the web server
#
opts = {
  :page_title => 'Vizualisation Demo',
  :use_tabs => [:graph]
  # :tabs => {
    # :foo => {:name => 'Foo', :order => 1, :class => Foo},
    # :goo => {:name => 'Goo', :order => 3}
  # }
}
require 'omf_web'
OMF::Web.start(opts)
