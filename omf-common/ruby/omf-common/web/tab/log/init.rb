require 'omf-common/web/tab/log/logServlet'

include OMF::Common
opts = {
    :name => :log, 
    :priority => 400, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Common::Web.registerService OMF::Common::Web::Log, opts
