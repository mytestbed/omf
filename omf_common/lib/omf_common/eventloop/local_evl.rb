

module OmfCommon
  class Eventloop
    # Implements a simple eventloop which only deals with timer events
    #
    class Local < Eventloop
      
      def initialize(opts = {}, &block)
        super
        @tasks =  []
        @running = false
        after(0, &block) if block
      end
      
      # Execute block after some time
      #
      # @param [float] delay in sec
      # @param [block] block to execute
      #
      def after(delay_sec, &block)
        @tasks << [Time.now + delay_sec, block]
      end
      
      # Periodically call block every interval_sec
      #
      # @param [float] interval in sec
      # @param [block] block to execute
      #
      def every(interval_sec, &block)
        @tasks << [Time.now + interval_sec, block, :periodic => interval_sec]
      end
      
      # Call 'block' in the context of a separate thread.
      #
      def defer(&block)
        @logger.note("DEFER")
        Thread.new do
          begin
            block.call()
          rescue Exception => ex
            @logger.error "Exception '#{ex}'"
            @logger.debug ex.backtract.join("\n\t")
          end
        end
      end
      
      
      def stop 
        @running = false
      end
      
      def run(&block)
        after(0, &block) if block
        return if @running
        @running = true
              
        while @running do
          now = Time.now
          @tasks = @tasks.sort
          while @tasks[0] && @tasks[0][0] <= now
            # execute
            t = @tasks.shift
            debug "Executing Task #{t}"
            block = t[1]
            block.arity == 0 ? block.call : block.call(self)
            now = Time.now
            # Check if periodic
            if interval = ((t[2] || {})[:periodic])
              if (next_time = t[0] + interval) < now
                warn "Falling behind with periodic task #{t[1]}"
                next_time = now + interval
              end
              @tasks << [next_time, t[1], :periodic => interval]
            end
          end
          # by now, there could have been a few more tasks added, so let's sort again
          @tasks = @tasks.sort
          if @tasks.empty?
            # done
            @running = false
          else
            if (delay = @tasks[0][0] - Time.now) > 0
              debug "Sleeping #{delay}"
              sleep delay
            end
          end
        end
      end      
    end # class
  end
end
      