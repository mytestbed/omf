
require 'omf-web/tab/two_column/two_column_service'

# This tab displays multiple widgets in a 2 column arrangement 
# where the +left+ column is stacking multiple widgets as is 
# the +right+.
#
OMF::Web::Tab.register_tab(
    :id => :two_column,
    :priority => 200, 
    :def_enabled => false, 
    :class => OMF::Web::Tab::TwoColumn::TwoColumnService,
    :topts => { 
      :layout => :r_66_33,
      # :left => [],
      # :right => []
    }
)



