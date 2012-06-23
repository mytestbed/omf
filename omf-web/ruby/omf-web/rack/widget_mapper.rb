
require 'omf_common'
require 'rack'
require 'omf-web/session_store'
require 'omf-web/widget'
OMF::Web::Theme.require 'widget_page' 
      
module OMF::Web::Rack 
       
  class WidgetMapper < MObject

    def initialize(opts = {})
      @opts = opts
      @tabs = {}
    end
    
    def call(env)
      req = ::Rack::Request.new(env)
      sessionID = req.params['sid']
      if sessionID.nil? || sessionID.empty?
        sessionID = "s#{(rand * 10000000).to_i}"
      end
      Thread.current["sessionID"] = sessionID
      
      body, headers = render_page(req)
      if headers.kind_of? String
        headers = {"Content-Type" => headers}
      end
      [200, headers, body] 
    end
    
    def render_page(req)
      
      opts = @opts.dup
      opts[:prefix] = req.script_name
      opts[:request] = req      
      opts[:path] = req.path_info

      p = req.path_info
      p = '/' if p.empty?
      widget_name = p.split('/')[1]
      unless widget_name
        return render_widget_list(opts)
      end
      widget_name = opts[:widget_name] = widget_name.to_sym
      begin
        widget = OMF::Web::Widget.create_widget(widget_name)
        page = OMF::Web::Theme::WidgetPage.new(widget, opts)
        return [page.to_html, 'text/html']
      rescue Exception => ex
        warn "Request for unknown widget '#{widget_name}':(#{ex})"
        opts[:flash] = {:alert => %{Unknonw widget '#{widget_name}'.}}
        [OMF::Web::Theme::WidgetPage.new(nil, opts).to_html, 'text/html']
      end
    end

    def render_widget_list(popts)
      wlist = OMF::Web::Widget.registered_widgets
      [wlist.to_json, 'text/json']
    end
     
  end # WidgetMapper
  
end # OMF::Web::Rack 


      
        
