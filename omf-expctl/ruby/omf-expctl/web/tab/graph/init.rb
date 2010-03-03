require 'omf-expctl/web/tab/graph/graphServlet'

include OMF::ExperimentController
Web.registerService Web::Graph, :name => :graph, :priority => 400, :def_enabled => false
