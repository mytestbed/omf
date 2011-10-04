
require 'omf-common/mobject'
require 'omf-web/session_store'

module OMF::Web::Rack
      
  class UpdateHandler < MObject
    
    def initialize(opts = {})
    end
    
    
    def call(env)
      req = ::Rack::Request.new(env)
      begin
        id = req.params['id'] || ""
        comp_path = id.split(':')
        h = OMF::Web::SessionStore.find_tab_from_path(comp_path)
        Thread.current["sessionID"] = h[:sid]
        tab_inst = h[:tab_inst]
        sub_path = h[:sub_path]
        body, headers = tab_inst.on_update(req, sub_path.dup)
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


      
        
