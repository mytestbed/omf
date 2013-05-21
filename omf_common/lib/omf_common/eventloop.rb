module OmfCommon
  # Providing event loop support.
  class Eventloop

    @@providers = {
      em: {
        require: 'omf_common/eventloop/em',
        constructor: 'OmfCommon::Eventloop::EventMachine'
      },
      local: {
        require: 'omf_common/eventloop/local_evl',
        constructor: 'OmfCommon::Eventloop::Local'
      }
    }
    @@instance = nil
    @@on_stop_proc = []

    #
    # opts:
    #   :type - eventloop provider
    #   :provider - custom provider (opts)
    #     :require - gem to load first (opts)
    #     :constructor - Class implementing provider
    #
    def self.init(opts, &block)
      if @@instance
        raise "Eventloop provider already iniitalised"
      end
      unless provider = opts[:provider]
        provider = @@providers[opts[:type].to_sym]
      end
      unless provider
        raise "Missing Eventloop provider declaration. Either define 'type' or 'provider'"
      end

      require provider[:require] if provider[:require]

      if class_name = provider[:constructor]
        provider_class = class_name.split('::').inject(Object) {|c,n| c.const_get(n) }
        inst = provider_class.new(opts, &block)
      else
        raise "Missing provider creation info - :constructor"
      end
      @@instance = inst
      inst
    end

    def self.instance
      @@instance
    end

    # Execute block after some time
    #
    # @param [float] delay in sec
    # @param [block] block to execute
    #
    def after(delay_sec, &block)
      raise "Missing implementation 'after'"
    end

    # Periodically call block every interval_sec
    #
    # @param [float] interval in sec
    # @param [block] block to execute
    #
    def every(interval_sec, &block)
      raise "Missing implementation 'every'"
    end

    # Call 'block' in the context of a separate thread.
    #
    def defer(&block)
      raise "Missing implementation 'defer'"
    end

    # Block calling thread until eventloop exits
    def join()
      raise "Missing implementation 'join'"
    end

    def run()
      raise "Missing implementation 'run'"
    end

    def stop()
      @@on_stop_proc.each do |block|
        begin
          block.call()
        rescue  => ex
          error "Exception '#{ex}'"
          debug "#{ex}\n\t#{ex.backtrace.join("\n\t")}"
        end
      end
    end

    # Calling 'block' before stopping eventloop
    #
    def on_stop(&block)
      @@on_stop_proc << block
    end

    # Calling 'block' when having trapped an INT signal
    #
    def on_int_signal(&block)
      # trap(:INT)
      warn "Missing implementation 'on_int_signal'"
    end

    # Calling 'block' when having trapped a TERM signal
    #
    def on_term_signal(&block)
      # trap(:TERM) {}
      warn "Missing implementation 'on_term_signal'"
    end

    private
    def initialize(opts = {}, &block)
      #run(&block) if block
    end

  end
end