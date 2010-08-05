require 'web/tab/auto/autoServlet'

include OMF::Admin

opts = {
    :name => :auto, 
    :priority => 100, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Admin::Web.registerService Web::Auto, opts

