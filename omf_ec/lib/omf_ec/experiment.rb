require 'hashie'
require 'singleton'

module OmfEc
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

    def id
      @name.nil? ? @id : "#{@name}-#{@id}"
    end

    def process_events
      self.events.find_all { |v| v[:callback] }.each do |event|
        if event[:trigger].call
          self.events.delete(event) if event[:consume_event]
          event[:callback].call
        end
      end
    end

    # Purely for backward compatibility
    class << self
      def done
        self.comm.disconnect(delete_affiliations: true)
        self.comm.add_timer(5) do
          self.comm.disconnect
        end
      end
    end
  end
end
