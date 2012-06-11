

module OMF::Web::Widget
      
  # Module containing all the layout widgets
  #
  module Layout

    def self.create_layout_widget(type, wdescr)
      case type.split('/')[1].to_s
      when 'one_column'
        require 'omf-web/widget/layout/one_column_layout'
        return OMF::Web::Widget::Layout::OneColumnLayout.new(wdescr)        
      when 'two_columns'
        require 'omf-web/widget/layout/two_columns_layout'
        return OMF::Web::Widget::Layout::TwoColumnsLayout.new(type, wdescr)        
      when 'stacked'
        require 'omf-web/widget/layout/stacked_layout'
        return OMF::Web::Widget::Layout::StackedLayout.new(wdescr)        
      when 'tabbed'
        require 'omf-web/widget/layout/tabbed_layout'
        return OMF::Web::Widget::Layout::TabbedLayout.new(wdescr)        
      when 'flow'
        require 'omf-web/widget/layout/flow_layout'
        return OMF::Web::Widget::Layout::FlowLayout.new(wdescr)        
      else
        raise "Unknown layout type '#{type}'"
      end
      
    end
  end
end