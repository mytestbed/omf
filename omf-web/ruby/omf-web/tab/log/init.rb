

require 'omf-web/tab/log/log_service'

OMF::Web::Tab.register_tab(
    :id => :log,
    :name => 'Log', 
    :priority => 900, 
    :def_enabled => true, 
    :class => OMF::Web::Tab::Log::LogService
)

