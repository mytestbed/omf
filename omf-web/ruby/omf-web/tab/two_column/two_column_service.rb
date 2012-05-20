
require 'omf-web/tab/abstract_service'
require 'omf-web/widget/abstract_widget'

module OMF::Web::Tab::TwoColumn
  
  class TwoColumnService < OMF::Web::Tab::AbstractService
    
    def initialize(tab_id, opts)
      super
      debug "New TwoColumn Service: #{opts.inspect}"
      @lwidgets = (opts[:left] || []).collect do |wd| 
        OMF::Web::Widget::AbstractWidget.create_widget(wd) 
      end
      @rwidgets = (opts[:right] || []).collect do |wd| 
        OMF::Web::Widget::AbstractWidget.create_widget(wd)
      end
    end 
    
    def show(req, opts)
      OMF::Web::Theme.require 'two_column_page'
      page = OMF::Web::Theme::TwoColumnPage.new(@lwidgets, @rwidgets, opts.merge(@opts))
      [page.to_html, 'text/html']
    end

  end # TwoColumn
  
  
end # OMF::Web::Tab::TwoColumn