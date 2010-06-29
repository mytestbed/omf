require 'omf-common/web/tab/graph2/graphServlet'

include OMF::Common
opts = {
    :name => :graph2, 
    :priority => 400, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__)
}
Web.registerService Web::Graph2, opts
