
require 'omf-common/mobject'
require 'omf-web/session_store'

module OMF::Web::Rack
      
  class UpdateHandler < MObject
    
    def initialize(opts = {})
    end
    
    
    def call(env)
      req = ::Rack::Request.new(env)
      begin
        sid = req.params['sid']
        unless sid
          error "Called update without a 'sid' (#{req.inspect})"
          raise 'Missing <sid>'
        end
        Thread.current["sessionID"] = sid
        
        wid = req.params['wid']
        unless wid
          error "Called update without a 'wid' (#{req.inspect})"
          raise 'Missing <wid>'
        end
        
        widget = OMF::Web::SessionStore[wid]
        unless widget
          error "Can't find widget <#{wid}>"
          raise 'Can dfind widget'
        end
        body, headers = widget.on_update(req)
        
        # comp_path = id.split(':')
        # h = OMF::Web::SessionStore.find_tab_from_path(comp_path)
        # Thread.current["sessionID"] = h[:sid]
        # tab_inst = h[:tab_inst]
        # sub_path = h[:sub_path]
        #body, headers = tab_inst.on_update(req, sub_path.dup)
      rescue Exception => ex
        b = ex.to_s + "\n" + ex.backtrace.join("\n")
        return [412, {"Content-Type" => 'text'}, b]
      end
      
      if headers.kind_of? String
        headers = {"Content-Type" => headers}
      end
      [200, headers, body] 
    end
  end # UpdateHandler
  
end # OMF:Web


      
        
