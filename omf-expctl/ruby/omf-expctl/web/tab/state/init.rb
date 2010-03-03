require 'omf-expctl/web/tab/state/xmlStateServlet'

include OMF::ExperimentController
Web.registerService Web::State, :name => :state, :priority => 900, :def_enabled => true
