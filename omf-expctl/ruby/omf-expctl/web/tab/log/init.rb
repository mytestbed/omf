require 'omf-expctl/web/tab/log/logServlet'

include OMF::ExperimentController
Web.registerService Web::Log, :name => :log, :priority => 400, :def_enabled => true
