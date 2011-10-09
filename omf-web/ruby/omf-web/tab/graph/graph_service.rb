


require 'json'
require 'omf-common/mobject'
require 'omf-web/tab/graph/graph_card'

require 'omf-web/widget/graph/graph'
require 'omf-web/widget/graph/graph_widget'

module OMF::Web::Tab::Graph
  
  class GraphService < MObject
    
    def initialize(tab_id, opts)
      debug "New GraphService: #{opts.inspect}"
      @widgets = []
      @tab_id = tab_id
    end
    
    def show(req, opts)
      gid = opts[:graph_id] = (req.params['gid'] || 0).to_i
      unless (widget = @widgets[gid])
        if gd = OMF::Web::Widget::Graph[gid]
          addr = [req.params['sid'], @tab_id, gid].join(':')
          widget = @widgets[gid] = OMF::Web::Widget::Graph::GraphWidget.new(addr, gd)
        else
          if OMF::Web::Widget::Graph.count > 0
            opts[:flash] = {:alert => "Unknown graph id '#{gid}'"}
          else
            opts[:flash] = {:alert => "No graphs defined"}
          end                    
        end
      end
      if opts[:widget] = widget
        opts[:card_title] = widget.name
      end
      [GraphCard.new(widget, opts).to_html, 'text/html']
    end
    
    # A dynamic grph may open a web socket back to this service. Find the 
    # respective graph widget and hand it on.
    #
    def on_ws_open(ws, sub_path = [])
      puts ">>>> Service: ON_WS_OPEN"      
      w = find_widget(sub_path.shift)
      w.on_ws_open(ws)
    end
    
    def on_ws_close(ws, sub_path = [])
      w = find_widget(sub_path.shift)      
      w.on_ws_close(ws)
    end
    
    #body, headers = tab_inst.on_update(req, sub_path.dup)
    def on_update(req, path)
      #puts ">>>> ON_UPDATE"
      w = find_widget(path[0])
      body = w.on_update()
      [body.to_json, "text/json"]
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
