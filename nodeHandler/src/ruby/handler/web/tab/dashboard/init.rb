require 'handler/web/tab/dashboard/dashboardServlet'

include OMF::ExperimentController
Web.registerService Web::Dashboard, 0
