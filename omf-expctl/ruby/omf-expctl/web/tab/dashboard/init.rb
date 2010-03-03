require 'omf-expctl/web/tab/dashboard/dashboardServlet'

include OMF::ExperimentController
Web.registerService Web::Dashboard, :name => :dashboard, :priority => 0, :def_enabled => true