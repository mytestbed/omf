
require 'omf-web/tab/graph/graph_service'

# A graph tab displays a sub menu listing all the graphs
# registered with +OMF::Web::Widget::Graph.addGraph.
# Any of these graphs can be displayed individually by 
# selecting its name from the sub menu. The actual graph
# rendering is performed by +OMF::Web::Widget::Graph::GraphWidget+
#
OMF::Web::Tab.register_tab(
    :id => :graph,
    :name => 'Graph', 
    :priority => 400, 
    :def_enabled => true, 
    :class => OMF::Web::Tab::Graph::GraphService
)

