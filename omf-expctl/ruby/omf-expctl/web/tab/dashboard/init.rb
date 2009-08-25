require 'omf-expctl/web/tab/dashboard/dashboardServlet'

include OMF::ExperimentController
Web.registerService Web::Dashboard, 0
