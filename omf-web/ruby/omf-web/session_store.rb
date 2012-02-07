
require 'omf_common'


module OMF::Web
        
  # Keeps session state.
  #
  # TODO: Implement cleanup thread
  #
  class SessionStore < MObject
    @@sessions = {}
    
    def self.[](key)
      self.session[key]
    end
    
    def self.[]=(key, value)
      self.session[key] = value
    end

    def self.session(sid = nil)
      unless sid
        sid = Thread.current["sessionID"]
      end
      unless sid
        raise "Missing session id 'sid'"
      end
      
      session = @@sessions[sid] ||= {:content => {}}
      #puts "STORE>> #{sid} = #{session[:content].keys.inspect}"
      session[:ts] = Time.now
      session[:content]
    end    
    
    def self.find_tab_from_path(comp_path)
      sid = comp_path.shift
      unless session = self.session(sid)
        raise "Can't find session '#{sid}', may have timed out"
      end
      tid = comp_path.shift.to_sym
      unless tab_inst = session[tid] 
        raise "Can't find tab '#{tid}'"   
      end
      {:sid => sid, :tab_inst => tab_inst, :sub_path => comp_path}
    end
  end # SessionStore

end # OMF:Web


      
        
