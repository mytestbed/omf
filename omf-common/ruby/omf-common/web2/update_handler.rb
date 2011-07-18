
require 'omf-common/mobject'

module OMF::Common::Web2
      
  class UpdateHandler < MObject
    
    def initialize(opts = {})
    end
    
    
    def call(env)
      req = ::Rack::Request.new(env)
      begin
        id = req.params['id'] || ""
        comp_path = id.split(':')
        h = self.find_tab_from_path(comp_path)
      rescue Exception => ex
        return [412, nil, ex.to_s]
      end
      
      Thread.current["sessionID"] = h[:sid]
      tab_inst = h[:tab_inst]
      body, headers = tab_inst.on_update(req, h[])
      if headers.kind_of? String
        headers = {"Content-Type" => headers}
      end
      [200, headers, body] 
    end
  end # UpdateHandler
  
end # OMF:Common::Web2


      
        
