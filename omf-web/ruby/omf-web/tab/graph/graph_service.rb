


require 'json'
require 'omf-web/tab/tabbed_widgets/tabbed_widgets_service'
require 'omf-web/widget/abstract_widget'

module OMF::Web::Tab::Graph
  
  class GraphService < OMF::Web::Tab::TabbedWidgets::TabbedWidgetsService
    
    def initialize(tab_id, opts)
      opts[:widgets] ||= OMF::Web::Widget::AbstractWidget.registered_widgets().select do |key, descr|
        (descr[:type] || '_').to_sym == :data
      end.sort do |a, b|
        a[0].to_s <=> b[0].to_s # sorting by ids
      end.collect do |name, descr| 
        name
      end
      super
    end
    
  end # GraphService
    
end
