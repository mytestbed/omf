
require 'omf-common/mobject2'
OMF::Common::Loggable.init_log 'demo'


require 'omf-oml/table'
require 'omf-web/widget/code/code'
require 'omf-web/widget/graph/graph'

Dir.glob("#{File.dirname(__FILE__)}/data_sources/*.rb").each do |fn|
  load fn
end

require 'yaml'
Dir.glob("#{File.dirname(__FILE__)}/*.yaml").each do |fn|
  h = YAML.load_file(fn)
  if w = h['widget']
    puts "registering widget '#{w}'"
    OMF::Web.register_widget w
  end
end

require 'omf-web/tab/two_column/two_column_service'
require 'omf-web/tab'
$lwidgets = []
$rwidgets = []
OMF::Web::Tab.register_tab(
    :id => :dashboard,
    :name => 'Dashboard', 
    :priority => 999, 
    :class => OMF::Web::Tab::TwoColumn::TwoColumn,
    :opts => { 
      :layout => :layout_66_33,
      :left => $lwidgets,
      :right => $rwidgets
    }
)

# Configure the web server
#
opts = {
  :page_title => 'Vizualisation Demo',
  :use_tabs => [:graph, :dashboard]
  # :tabs => {
    # :foo => {:name => 'Foo', :order => 1, :class => Foo},
    # :goo => {:name => 'Goo', :order => 3}
  # }
}
require 'omf_web'
OMF::Web.start(opts)
