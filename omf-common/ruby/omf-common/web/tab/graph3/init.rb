require 'omf-common/web/tab/graph3/graphServlet'

include OMF::Common
opts = {
    :name => :graph3, 
    :priority => 400, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Common::Web.registerService OMF::Common::Web::Graph3, opts
