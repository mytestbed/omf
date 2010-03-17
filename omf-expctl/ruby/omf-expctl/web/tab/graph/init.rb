require 'omf-expctl/web/tab/graph/graphServlet'

include OMF::ExperimentController
opts = {
    :name => :graph, 
    :priority => 400, 
    :def_enabled => false, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Common::Web.registerService Web::Graph, opts
