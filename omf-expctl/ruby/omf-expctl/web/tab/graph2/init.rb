require 'omf-expctl/web/tab/graph2/graphServlet'

include OMF::ExperimentController
opts = {
    :name => :graph2, 
    :priority => 400, 
    :def_enabled => false, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Common::Web.registerService Web::Graph2, opts
