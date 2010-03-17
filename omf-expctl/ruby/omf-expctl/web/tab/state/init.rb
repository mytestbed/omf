require 'omf-expctl/web/tab/state/xmlStateServlet'

include OMF::ExperimentController::Web
opts = {
    :name => :stats, 
    :priority => 900, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Common::Web.registerService State, opts
