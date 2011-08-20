require 'omf-common/web2/tab/log/log_service'
register_tab(
    :id => :log,
    :name => 'Log', 
    :priority => 900, 
    :def_enabled => true, 
    :class => OMF::Common::Web2::Log::LogService
)

