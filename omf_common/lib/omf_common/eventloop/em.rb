require 'eventmachine'

module OmfCommon
  class Eventloop
    # Implements a simple eventloop which only deals with timer events
    #
    class EventMachine < Eventloop

      def initialize(opts = {}, &block)
        super
        @deferred =  []
        @deferred << block if block
      end

      # Execute block after some time
      #
      # @param [Float] delay in sec
      def after(delay_sec, &block)
        if EM.reactor_running?
          EM.add_timer(delay_sec, &block)
        else
          @deferred << lambda do
            EM.add_timer(delay_sec, &block)
          end
        end
      end
      
      # Call 'block' in the context of a separate thread.
      #
      def defer(&block)
        raise "Can't handle 'defer' registration before the EM is up" unless EM.reactor_running?
        EM.defer do
          begin
            block.call()
          rescue Exception => ex
            error "Exception '#{ex}'"
            debug "#{ex}\n\t#{ex.backtrace.join("\n\t")}"
          end
        end
      end

      # Periodically call block every interval_sec
      #
      # @param [Float] interval in sec
      def every(interval_sec, &block)
        # to allow canceling the periodic timer we need to 
        # hand back a reference to it which responds to 'cancel'
        # As this is getting rather complex when allowing for 
        # registration before the EM is up and running, we simply throw 
        # and exception at this time.
        raise "Can't handle 'every' registration before the EM is up" unless EM.reactor_running?
        # if EM.reactor_running?
          # EM.add_periodic_timer(interval_sec, &block)
        # else
          # @deferred << lambda do
            # EM.add_periodic_timer(interval_sec, &block)
          # end
        # end
        EM.add_periodic_timer(interval_sec) do
          begin
            block.call()
          rescue Exception => ex
            error "Exception '#{ex}'"
            debug "#{ex}\n\t#{ex.backtrace.join("\n\t")}"
          end
        end      
      end

      def run(&block)
        EM.run do
          @deferred.each { |proc| proc.call }
          @deferred = nil
          if block
            begin
              block.arity == 0 ? block.call : block.call(self)
            rescue Exception => ex
              error "While executing run block - #{ex}"
              debug ex.backtrace.join("\n\t")
            end
          end
        end
      end

      def stop()
        EM.stop
      end
    end # class
  end
end

