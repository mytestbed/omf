require 'web/tab/setup/setupServlet'

include OMF::Admin::Web
opts = {
    :name => :stats, 
    :priority => 900, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Admin::Web.registerService Setup, opts
