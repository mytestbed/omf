require 'omf-common/web/tab/graph/graphServlet'

include OMF::Common
opts = {
    :name => :graph, 
    :priority => 400, 
    :def_enabled => false, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Common::Web.registerService OMF::Common::Web::Graph, opts
