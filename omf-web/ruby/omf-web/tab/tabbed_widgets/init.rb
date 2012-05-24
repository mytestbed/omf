
require 'omf-web/tab/tabbed_widgets/tabbed_widgets_service'

# A tab displaying a sub menu listing all the associated
# widgets as well as one of the widgets selected.
#
OMF::Web::Tab.register_tab(
    :id => :tabbed_widgets,
    :priority => 100, 
    :def_enabled => false, 
    :class => OMF::Web::Tab::TabbedWidgets::TabbedWidgetsService
)

