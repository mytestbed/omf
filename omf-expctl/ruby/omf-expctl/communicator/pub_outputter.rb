require 'rubygems'
require 'monitor'
require 'thread'
require 'log4r/outputter/outputter'

module OMF; module EC; module Communicator; end end end

module OMF::EC::Communicator
  
  class PubOutputter < Log4r::Outputter
    include MonitorMixin
      
    def initialize(name = 'publog', hash={})
      super(name, hash)
      @queue = Queue.new
      _publish
    end
    
    # Can't allow log level to be set to DEBUG as sending log mesages
    # does also create new log messages which create even more.
    #
    def level=(level)
      if (level < 2)
        Logger.log_internal(4) do "PubOutputter: Can't allow log level to be set to DEBUG" end
        level = 2
      end
      super
    end
    
    def canonical_log(event)
      msg ={}
      msg[:logger] = event.fullname
      msg[:level] = event.level
      msg[:level_name] = Log4r::LNAMES[event.level]
      msg[:data] = event.data
      if event.tracer
        msg[:tracer] = event.tracer
      end
      @queue << msg 
    end
    
    private 
    
    def _publish
      Thread.new do
        begin
          comms = ECCommunicator.instance
          # The communicator won't be ready when we come here, let's wait for that
          while ! comms.initialized?
            sleep 2
          end
          
          while (msg = @queue.pop)
            comms.send_log_message(msg)
          end
        rescue Exception => ex
          Logger.log_internal(4) do "PubOutputter: while sending log message #{ex}" end
        end
      end
    end

  end # PubOutputter
  
end # module
  