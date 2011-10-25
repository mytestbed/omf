
#require 'json'
require 'omf-common/mobject'
require 'omf-web/widget/code'
require 'omf-web/widget/code/code_widget'
#require 'omf-web/tab/code/code_card'
require 'omf-web/tab/common/multi_card_page'

#require 'omf-web/widget/graph/graph'
#require 'omf-web/widget/graph/graph_widget'

module OMF::Web::Tab::Code
  
  class CodeService < MObject
    
    def initialize(tab_id, opts)
      debug "New CodeService: #{opts.inspect}"
      @widgets = []
      @tab_id = tab_id
    end 
    
    def show(req, opts)
      tid = opts[:card_id] = (req.params['tid'] || 0).to_i
      unless (widget = @widgets[tid])
        if descr = OMF::Web::Widget::Code[tid]
          widget = @widgets[tid] = OMF::Web::Widget::Code::CodeWidget.new(descr)
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
      
      page = OMF::Web::Tab::MultiCardPage.new(widget, :code, OMF::Web::Widget::Code, opts)
      [page.to_html, 'text/html']
    end

  end # CodeService
  
  
end # OMF::Web::Tab::Code