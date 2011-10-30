    
require 'omf-web/tab/common/abstract_service'

require 'omf-web/session_store'
require 'omf-web/widget/log/log_widget'


module OMF::Web::Tab::Log
  class LogService < OMF::Web::Tab::AbstractService

    def initialize(tab_id, opts = {})
      @tab_id = tab_id
      @opts = opts
      @widget = OMF::Web::Widget::Log::LogWidget.new(opts)
    end
    
    def show(req, opts)
      opts[:card_title] ||= 'Log'
      OMF::Web::Theme.require 'widget_page'
      [OMF::Web::Theme::WidgetPage.new(@widget, opts).to_html, 'text/html']
    end
  end # LogService   
 
end # module
  