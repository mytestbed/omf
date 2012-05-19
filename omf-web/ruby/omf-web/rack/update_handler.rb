
require 'omf-common/mobject'
require 'omf-web/session_store'

module OMF::Web::Rack
      
  class MissingArgumentException < Exception; end

  class UpdateHandler < MObject
    
    def initialize(opts = {})
    end
    
    
    def call(env)
      req = ::Rack::Request.new(env)
      begin
        sid = req.params['sid']
        unless sid
          raise MissingArgumentException.new "Called update without a 'sid' (#{req.inspect})"
        end
        Thread.current["sessionID"] = sid
        
        ds_id = req.path_info[1 .. -1].to_sym
        ds_proxy = OMF::Web::SessionStore[ds_id]
        unless ds_proxy
          raise MissingArgumentException.new "Can't find data source proxy '#{ds_id}'"
        end
        body, headers = ds_proxy.on_update(req)
        
        # comp_path = id.split(':')
        # h = OMF::Web::SessionStore.find_tab_from_path(comp_path)
        # Thread.current["sessionID"] = h[:sid]
        # tab_inst = h[:tab_inst]
        # sub_path = h[:sub_path]
        #body, headers = tab_inst.on_update(req, sub_path.dup)
      rescue MissingArgumentException => mex
        debug mex
        return [412, {"Content-Type" => 'text'}, mex.to_s]
      rescue Exception => ex
        error ex
        debug ex.to_s + "\n\t" + ex.backtrace.join("\n\t")
        return [500, {"Content-Type" => 'text'}, ex.to_s]
      end
      
      if headers.kind_of? String
        headers = {"Content-Type" => headers}
      end
      [200, headers, body] 
    end
  end # UpdateHandler
  
end # OMF:Web


      
        
