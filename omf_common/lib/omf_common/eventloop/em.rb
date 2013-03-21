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

      # Periodically call block every interval_sec
      #
      # @param [Float] interval in sec
      def every(interval_sec, &block)
        if EM.reactor_running?
          EM.add_periodic_timer(interval_sec, &block)
        else
          @deferred << lambda do
            EM.add_periodic_timer(interval_sec, &block)
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

