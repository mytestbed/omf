require 'omf-expctl/web/tab/log/logServlet'

include OMF::ExperimentController
opts = {
    :name => :log, 
    :priority => 400, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Common::Web.registerService Web::Log, opts
