
require 'rack/websocket'
require 'omf-common/mobject'

module OMF::Common::Web2
  
  class WebsocketHandler < ::Rack::WebSocket::Application
    def on_open(env)
  
      # EM.add_timer(15) do
        # send_data "This message should show-up 15 secs later"
      # end
      puts "client connected2"      
    end
  
    def on_message(env, msg)
      begin
        puts "message received: " + msg
        
        ma = msg.split(':')
        cmd = ma.shift.to_sym
        if (cmd == :id)
          begin
            h = SessionStore.find_tab_from_path(ma)
          rescue Exception => ex
            send_data("{error: '#{ex.to_s}'}")
            return
          end
          Thread.current["sessionID"] = h[:sid]
          @tab_inst = h[:tab_inst]
          @sub_path = h[:sub_path]
          @tab_inst.on_ws_open(self, @sub_path.dup)
        else
          send_data("{error: 'Unknown command -#{cmd}-'}")
        end
      rescue Exception => ex
        MObject.error('web::websocket', ex)
      end
      puts "message processed"      
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
  
end # OMF::Common::Web2