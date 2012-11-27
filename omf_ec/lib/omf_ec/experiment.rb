require 'hashie'
require 'singleton'

module OmfEc
  # Experiment class to hold relevant state information
  #
  class Experiment
    include Singleton

    attr_accessor :property,:state, :comm, :groups, :events, :name

    def initialize
      @id = Time.now.utc.iso8601
      self.property ||= Hashie::Mash.new
      self.comm ||= OmfCommon::Comm.new(:xmpp)
      self.state ||= []
      self.groups ||= []
      self.events ||= []
    end

    # Unique experiment id
    def id
      @name.nil? ? @id : "#{@name}-#{@id}"
    end

    # Parsing user defined events, checking conditions against internal state, and execute callbacks if triggered
    def process_events
      EM.next_tick do
        self.events.find_all { |v| v[:callbacks] && !v[:callbacks].empty? }.each do |event|
          if event[:trigger].call(self.state)
            info "Event triggered: '#{event[:name]}'"
            self.events.delete(event) if event[:consume_event]

            # Last in first serve callbacks
            event[:callbacks].reverse.each do |callback|
              callback.call
            end
          end
        end
      end
    end

    # Purely for backward compatibility
    class << self
      # Disconnect communicator, try to delete any XMPP affiliations
      def done
        OmfEc.comm.disconnect(delete_affiliations: true)
        info "Exit in 5 seconds..."
        OmfEc.comm.add_timer(5) do
          OmfEc.comm.disconnect
        end
      end
    end
  end
end
