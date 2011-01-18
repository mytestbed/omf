require 'omf-common/web/tab/graph2/graphServlet'

include OMF::Common
opts = {
    :name => :graph2, 
    :priority => 400, 
    :def_enabled => false, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Common::Web.registerService OMF::Common::Web::Graph2, opts
