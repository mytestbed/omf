require 'omf-common/web/tab/code/codeServlet'

include OMF::Common

opts = {
    :name => :ec_code, 
    :priority => 200, 
    :def_enabled => true, 
    :view_dir => File.dirname(__FILE__),
    :on_configure => lambda do |klass|
            OConfig.add_observer() do |action, opts|
              if action == :load
                klass.addScript(opts)
              end 
            end
            OConfig.getLoadHistory.each do |sopts| 
              klass.addScript(sopts) 
            end
          end
      
}
OMF::Common::Web.registerService OMF::Common::Web::Code, opts

