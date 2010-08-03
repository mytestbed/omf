require 'web/tab/nodes/nodesServlet'

include OMF::Admin

opts = {
    :name => :nodes, 
    :priority => 200, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Admin::Web.registerService Web::Nodes, opts

