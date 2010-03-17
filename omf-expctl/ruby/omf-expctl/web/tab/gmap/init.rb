require 'omf-expctl/web/tab/gmap/gmapServlet'

include OMF::ExperimentController

opts = {
    :name => :map, 
    :priority => 400, 
    :def_enabled => false, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Common::Web.registerService Web::GMap, opts
