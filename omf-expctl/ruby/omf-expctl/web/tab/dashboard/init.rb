require 'omf-expctl/web/tab/dashboard/dashboardServlet'

include OMF::ExperimentController

opts = {
    :name => :dashboard, 
    :priority => 0, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Common::Web.registerService Web::Dashboard, opts