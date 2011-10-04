


require 'json'
require 'omf-common/mobject'
require 'omf-web/tab/graph/graph_card'

require 'omf-web/widget/graph/graph'
require 'omf-web/widget/graph/graph_widget'

module OMF::Web::Tab::Graph
  
  class GraphService < MObject
    
    def initialize(tab_id, opts)
      puts "GraphService: #{opts.inspect}"
      @widgets = []
      @tab_id = tab_id
    end
    
    def show(req, opts)
      #opts[:flash].clear
      #opts[:format] = req.params['format'] || 'graph'
      
      if widget = opts[:gd] = get_widget(req, opts)
        opts[:card_title] = widget.name
      end
      [GraphCard.new(widget, opts).to_html, 'text/html']
    end
    
    # A dynamic grph may open a web socket back to this service. Find the 
    # respective graph widget and hand it on.
    #
    def on_ws_open(ws, sub_path = [])
      widget_id = sub_path.shift
      unless (widget_id && (w = @widgets[widget_id.to_i]))
        raise "Unknown graph widget '#{widget_id}'"
      end
      w.on_ws_open(ws)
    end
    
    def on_ws_close(ws, sub_path = [])
      widget_id = sub_path.shift
      unless (widget_id && (w = @widgets[widget_id.to_i]))
        raise "Unknown graph widget '#{widget_id}'"
      end
      w.on_ws_close(ws)
    end
    
    #body, headers = tab_inst.on_update(req, sub_path.dup)
    def on_update(req, path)
      puts ">>>> ON_UPDATE #{path.inspect}"
      widget_id = path[0]
      unless (widget_id && (w = @widgets[widget_id.to_i]))
        raise "Unknown graph widget '#{widget_id}'"
      end
      body = w.update()
      # puts "DATA: #{gd.inspect}"
      [body.to_json, "text/json"]
    end

    def update(req, opts)
      gID = req.params['id']
      if (!@shown || gID.nil?)
        body = "ERROR: Missing 'id' or expired session"
      else
        if gx = Graph[gID.to_i]
          gd = GraphDescription.new(opts[:session_id], gx)
          body = {:data => gd.data.to_a, :opts => gx[:gopts]}
        else
          body = "ERROR: Unknonw graph '#{gID}'"
        end
      end
      # puts "DATA: #{gd.inspect}"
      [body.to_json, "text/json"]
    end
    
    private
    
    def get_widget(req, opts)
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
      widget
    end
  
  end # GraphService
  
end
