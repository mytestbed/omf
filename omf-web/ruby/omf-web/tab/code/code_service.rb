
#require 'json'
require 'omf-common/mobject'
require 'omf-web/widget/code'
require 'omf-web/widget/code/code_widget'
require 'omf-web/tab/code/code_card'

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
      wid = opts[:widget_id] = (req.params['wid'] || 0).to_i
      unless (widget = @widgets[wid])
        if sd = OMF::Web::Widget::Code[wid]
          addr = [req.params['wid'], @tab_id, wid].join(':')
          widget = @widgets[wid] = OMF::Web::Widget::Code::CodeWidget.new(addr, sd)
        else
          if OMF::Web::Widget::Code.count > 0
            opts[:flash] = {:alert => "Unknown script id '#{gid}'"}
          else
            opts[:flash] = {:alert => "No scripts defined"}
          end                    
        end
      end
      if opts[:widget] = widget
        opts[:card_title] = widget.name
      end
      #puts "WIDGET in SERVICE>>> #{widget.inspect}"
      [CodeCard.new(widget, opts).to_html, 'text/html']
    end

  end # CodeService
end # OMF::Web::Tab::Code