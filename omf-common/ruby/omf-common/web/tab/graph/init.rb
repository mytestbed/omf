require 'omf-common/web/tab/graph/graphServlet'

include OMF::Common
opts = {
    :name => :graph, 
    :priority => 400, 
    :def_enabled => false, 
    :view_dir => File.dirname(__FILE__)
}
Web.registerService Web::Graph, opts
