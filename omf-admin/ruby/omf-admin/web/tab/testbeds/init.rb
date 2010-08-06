require 'web/tab/testbeds/testbedsServlet'

include OMF::Admin
opts = {
    :name => :testbeds, 
    :priority => 300, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Admin::Web.registerService Web::Testbeds, opts
