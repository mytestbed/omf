require 'omf-expctl/web/tab/code/codeServlet'

include OMF::ExperimentController
Web.registerService Web::Code, 200
