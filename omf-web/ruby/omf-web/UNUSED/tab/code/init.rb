require 'omf-web/tab/code/code_service'

# A code tab displays a sub menu listing all the 
# scripts which were registered with the tab.
#
OMF::Web::Tab.register_tab(
    :id => :code,
    :name => 'Code', 
    :priority => 200, 
    :def_enabled => false, 
    :class => OMF::Web::Tab::Code::CodeService
)



