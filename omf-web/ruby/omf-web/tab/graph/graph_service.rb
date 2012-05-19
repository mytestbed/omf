


require 'json'
require 'omf-web/tab/common/abstract_service'

#require 'omf-web/widget/graph/graph'
require 'omf-web/widget/graph/graph_widget'

module OMF::Web::Tab::Graph
  
  class GraphService < OMF::Web::Tab::AbstractService
    
    def initialize(tab_id, opts)
      @widget_descrs = OMF::Web::Widget::AbstractWidget.registered_widgets().select do |key, descr|
        (descr[:type] || '_').to_sym == :data
      end.sort do |a, b|
        a[0].to_s <=> b[0].to_s # sorting by ids
      end.collect do |a| a[1] end
      @widget_names = @widget_descrs.collect { |d| d[:name] || 'Unknown' }
      @widgets = []     
    end
    
    def show(req, opts)
      tid = opts[:card_id] = (req.params['tid'] || 0).to_i
      unless (widget = @widgets[tid])
        if gd = @widget_descrs[tid]
          #addr = [req.params['sid'], @tab_id, gid].join(':')
          widget = @widgets[tid] = OMF::Web::Widget::Graph::GraphWidget.new(gd) #gd.create_widget
        else
          if @widget_descrs.count > 0
            opts[:flash] = {:alert => "Unknown graph id '#{tid}'"}
          else
            opts[:flash] = {:alert => "No graphs defined"}
          end                    
        end
      end
      if opts[:widget] = widget
        opts[:card_title] = widget.name
      end

      #require 'omf-web/tab/graph/graph_page'
      #page = GraphPage.new(widget, opts)
      OMF::Web::Theme.require 'multi_card_page'
      page = OMF::Web::Theme::MultiCardPage.new(widget, :graph, @widget_names, opts)
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
