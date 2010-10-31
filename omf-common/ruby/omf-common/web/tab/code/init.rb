require 'omf-common/web/tab/code/codeServlet'

include OMF::Common

opts = {
    :name => :code, 
    :priority => 200, 
    :def_enabled => false, 
    :view_dir => File.dirname(__FILE__),      
}
Web.registerService Web::Code, opts

