require 'omf-common/web/tab/log/logServlet'

include OMF::Common
opts = {
    :name => :log, 
    :priority => 400, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__)
}
Web.registerService Web::Log, opts
