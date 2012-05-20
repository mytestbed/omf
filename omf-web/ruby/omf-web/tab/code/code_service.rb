
require 'omf-web/tab/abstract_service'
require 'omf-web/widget/code/code'

module OMF::Web::Tab::Code
  
  class CodeService < OMF::Web::Tab::AbstractService
    
    def initialize(tab_id, opts)
      super
      @widgets = []
    end 
    
    def show(req, opts)
      tid = opts[:card_id] = (req.params['tid'] || 0).to_i
      unless (widget = @widgets[tid])
        if descr = OMF::Web::Widget::Code[tid]
          widget = @widgets[tid] = descr[:widget_class].new(descr) #.create_widget
        else
          if OMF::Web::Widget::Code.count > 0
            opts[:flash] = {:alert => "Unknown script id '#{tid}'"}
          else
            opts[:flash] = {:alert => "No scripts defined"}
          end                    
        end
      end
      if opts[:widget] = widget
        opts[:card_title] = widget.name
      end
      
      OMF::Web::Theme.require 'multi_card_page'
      page = OMF::Web::Theme::MultiCardPage.new(widget, :code, OMF::Web::Widget::Code, opts)
      [page.to_html, 'text/html']
    end

  end # CodeService
  
  
end # OMF::Web::Tab::Code