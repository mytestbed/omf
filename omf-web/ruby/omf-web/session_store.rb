
require 'omf_common'


module OMF::Web
        
  # Keeps session state.
  #
  # TODO: Implement cleanup thread
  #
  class SessionStore < MObject
    @@sessions = {}
    
    def self.[](sid)
      session = @@sessions[sid] ||= {:content => {}}
      session[:ts] = Time.now
      session[:content]
    end
    
    def self.find_tab_from_path(comp_path)
      sid = comp_path.shift
      unless session = self[sid]
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


      
        
