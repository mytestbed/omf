
#require 'omf-web/tab/log/log_outputter'
require 'omf-web/session_store'
require 'omf-web/tab/common/widget_page'
require 'omf-web/widget/log/log_widget'


module OMF::Web::Tab::Log
  class LogService < MObject

    def initialize(tab_id, opts = {})
      @tab_id = tab_id
      @opts = opts
      @widget = OMF::Web::Widget::Log::LogWidget.new(opts)
    end
    
    def show(req, opts)
      puts "Service: #{opts.inspect}"

      #puts "Widget>>> #{widget.to_html}"
      opts[:card_title] ||= 'Log'
      [OMF::Web::Tab::WidgetPage.new(@widget, opts).to_html, 'text/html']
    end
    
    # def update(req, opts)
      # id = req.params['id']
      # if (!@shown || gID.nil?)
        # body = "ERROR: Missing 'id' or expired session"
      # else
        # body = {:data => gd.data.to_a, :opts => gx[:gopts]}
      # end
      # # puts "DATA: #{body.inspect}"
      # [body.to_json, "text/json"]
    # end
  end # LogService   
 
end # module
  