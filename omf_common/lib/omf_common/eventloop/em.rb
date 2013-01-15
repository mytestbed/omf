
require 'eventmachine'

module OmfCommon
  module EventloopProvider
    # Implements a simple eventloop which only deals with timer events
    #
    class EventMachine < OmfCommon::Eventloop
      
      def initialize(opts = {}, &block)
        super
        @deferred =  []
        @running = false
        @deferred << block if block
      end
      
      # Execute block after some time
      #
      # @param [float] delay in sec
      # @param [block] block to execute
      #
      def after(delay_sec, &block)
        if @running
          EM.add_timer(delay_sec, &block)
        else
          @deferred << lambda do
            EM.add_timer(delay_sec, &block)
          end
        end
      end
      
      # Periodically call block every interval_sec
      #
      # @param [float] interval in sec
      # @param [block] block to execute
      #
      def every(interval_sec, &block)
        if @running
          EM.add_periodic_timer(interval_sec, &block)
        else
          @deferred << lambda do
            EM.add_periodic_timer(interval_sec, &block)
          end
        end
      end
      
      def run(&block)
        EM.run do 
          @running = true
          @deferred.each { |proc| proc.call }
          @deferred = nil
          if block
            block.arity == 0 ? block.call : block.call(self)
          end
        end
      end
      
      def stop()
        EM.stop
      end
      
    end # class
  end
end
      