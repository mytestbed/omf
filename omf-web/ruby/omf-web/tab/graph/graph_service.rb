


require 'json'
require 'omf-web/tab/common/abstract_service'

require 'omf-web/widget/graph/graph'
require 'omf-web/widget/graph/graph_widget'

module OMF::Web::Tab::Graph
  
  class GraphService < OMF::Web::Tab::AbstractService
    
    def initialize(tab_id, opts)
      debug "New GraphService: #{opts.inspect}"
      @widgets = []
      super
    end
    
    def show(req, opts)
      tid = opts[:card_id] = (req.params['tid'] || 0).to_i
      unless (widget = @widgets[tid])
        if gd = OMF::Web::Widget::Graph[tid]
          #addr = [req.params['sid'], @tab_id, gid].join(':')
          widget = @widgets[tid] = gd.create_widget
        else
          if OMF::Web::Widget::Graph.count > 0
            opts[:flash] = {:alert => "Unknown graph id '#{tid}'"}
          else
            opts[:flash] = {:alert => "No graphs defined"}
          end                    
        end
      end
      if opts[:widget] = widget
        opts[:card_title] = widget.name
      end

      require 'omf-web/tab/graph/graph_page'
      page = GraphPage.new(widget, opts)
      [page.to_html, 'text/html']
    end
    
    private
  
    def find_widget(widget_id)
      unless (widget_id && (widget = @widgets[widget_id.to_i]))
        raise "Unknown graph widget '#{widget_id}'"
      end
      widget
    end
    
  end # GraphService
    
end
