require 'omf-expctl/web/tab/code/codeServlet'

include OMF::ExperimentController

opts = {
    :name => :code, 
    :priority => 200, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__)
}
OMF::Common::Web.registerService Web::Code, opts

