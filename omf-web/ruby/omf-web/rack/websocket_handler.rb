
require 'rack/websocket'
#require 'omf-common/mobject2'
require 'omf-web/session_store'

module OMF::Web::Rack
  
  class WebsocketHandler < ::Rack::WebSocket::Application
#    include OMF::Common::MObject
  
    def on_message(env, msg)
      begin
        #puts "message received: " + msg
        
        ma = msg.split(':')
        cmd = ma.shift.to_sym
        if (cmd == :id)
          begin
            h = OMF::Web::SessionStore.find_tab_from_path(ma)
            Thread.current["sessionID"] = h[:sid]
            @tab_inst = h[:tab_inst]
            @sub_path = h[:sub_path]
            @tab_inst.on_ws_open(self, @sub_path.dup)
          rescue Exception => ex
            puts ">>>> ERROR: #{ex}"
            puts ">>>> ERROR: #{ex.backtrace.join("\n")}"
            send_data("{error: '#{ex.to_s}'}")
            return
          end

        else
          send_data("{error: 'Unknown command -#{cmd}-'}")
        end
      rescue Exception => ex
        MObject.error('web::websocket', ex)
      end
      #puts "message processed"      
    end
  
    def on_close(env)
      begin
        puts "client disconnected"
        @tab_inst.on_ws_close(self, @sub_path) if @tab_inst
        @tab_inst = nil
      rescue Exception => ex
        MObject.error('web::websocket', ex)
      end
    end

  end # WebsocketHandler
  
end # module