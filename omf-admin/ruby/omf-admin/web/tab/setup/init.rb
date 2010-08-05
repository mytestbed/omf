require 'web/tab/setup/setupServlet'

include OMF::Admin
opts = {
    :name => :stats, 
    :priority => 400, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Admin::Web.registerService Setup, opts
