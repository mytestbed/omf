require 'omf-common/web2/tab/graph/graph_service'

register_tab(
    :id => :graph,
    :name => 'Graph', 
    :priority => 400, 
    :def_enabled => true, 
    :class => OMF::Common::Web2::Graph::GraphService
)

