


require 'omf-web/tab/abstract_service'
require 'omf-web/widget/graph/graph_widget'

module OMF::Web::Tab::TabbedWidgets
  
  class TabbedWidgetsService < OMF::Web::Tab::AbstractService
    
    def initialize(tab_id, opts)
      super
      debug "New TabbedWidgets Service: #{opts.inspect}"      
      @widgets = (opts[:widgets] || []).collect do |wd| 
        OMF::Web::Widget::AbstractWidget.create_widget(wd) 
      end
    end
    
    def show(req, opts)
      sname = "tw:#{opts[:tab]}"
      tid = (req.params['tid'] || OMF::Web::SessionStore[sname, :tws] || 0).to_i
      opts[:card_id] = OMF::Web::SessionStore[sname, :tws] = tid
      unless (widget = @widgets[tid])
        if @widgets.count > 0
          opts[:flash] = {:alert => "Unknown widget id '#{tid}'"}
        else
          opts[:flash] = {:alert => "No widgets defined"}
        end                    
      end
      if opts[:widget] = widget
        opts[:card_title] = widget.name
      end

      OMF::Web::Theme.require 'multi_card_page'
      page = OMF::Web::Theme::MultiCardPage.new(widget, @widgets, opts.merge(@opts))
      [page.to_html, 'text/html']
    end

  end # TabbedWidgets
    
end
