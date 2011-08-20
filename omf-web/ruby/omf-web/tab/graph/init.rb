
require 'omf-web/tab/graph/graph_service'

OMF::Web::Tab.register_tab(
    :id => :graph,
    :name => 'Graph', 
    :priority => 400, 
    :def_enabled => true, 
    :class => OMF::Web::Tab::Graph::GraphService
)

