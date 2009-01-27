#require "../VisServer/XMLGenerator"
#require "../VisServer/Timer"
#require "../ConfigManager/ConfigMan"
require "socket"

module VisyoNet
  class VisServer < MObject
    
    def initialize(port = 8080)
      @listeningThread = nil
      @port = port
    end
    
    def run()
      iterate = 0
      if (@listeningThread == nil) 
        # start a new thread
        @listeningThread = Thread.new() {
          port = @port
          debug("Starting VisServer on #{@port} (#{@xmlGen})")
          server = TCPServer.new(@port)
          while (session = server.accept)
            begin
              debug("Accepted connection #{session}")
              session.each("\0") { |line| 
                debug("Received req from FLASH : |#{line}|")
                answer = processRequest(line)
                debug("Replying '#{answer}'")
                session.write(answer)
                #puts "Finished writing answer back to FLASH "+iterate.to_s 
                iterate = iterate+1
              }
              session.close 
            rescue Exception => ex
              begin 
                bt = ex.backtrace.join("\n\t")
                warn "Exception: #{ex} (#{ex.class})\n\t#{bt}"
              rescue Exception
              end
            end
          end
        }
        @listeningThread.run
      else
        # the thread is already running
        puts "Listening thread already running"
      end
    end
    
    
    def stop()
      if(@listeningThread != nil)
        Thread.kill(@listeningThread)
      end
    end
    
    
    def GetListeningThread()
      return @listeningThread
    end
    
    
    def processRequest(req)
      #start a timer to measure performance
      #      timer = Timer.new
      #      timer.start
      #        timer.stop
      #these are a series of requests posted by the Flash client
      
      debug("Process request #{req}")
      session = VisHttpServer.instance.getSession(nil)
      debug("Session: '#{session}'")
      # "<FlashClientRequest myData=\"getUpdates\" />\0"
      cmd = 'getUpdates'
      case cmd
      when 'getUpdates'
        ret = session.getVisModel.to_XML
      when 'getAllNodes'
        ret = @xmlGen.getAllNodes()
      when 'stepPlus'
        ret = @xmlGen.stepPlus()
      when 'stepMinus'
        ret = @xmlGen.stepMinus()
      when 'pause'
        ret = @xmlGen.pause()
      when 'stop'
        ret = @xmlGen.stop()
      else
        warn("Invalid request by Flash")
        ret = "<invalid><invalid/>\0"
      end
      return ret
    end
    
    
    @xmlGen = nil
    @listeningThread = nil
  end
end # module

