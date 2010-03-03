require 'omf-expctl/web/tab/code/codeServlet'

include OMF::ExperimentController
Web.registerService Web::Code, :name => :code, :priority => 200, :def_enabled => true
