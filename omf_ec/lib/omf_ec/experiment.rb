require 'hashie'
require 'singleton'

module OmfEc
  class Experiment
    include Singleton

    attr_accessor :property,:state, :comm, :groups, :events, :name, :plan

    def initialize
      @id = Time.now.utc.iso8601
      self.property ||= Hashie::Mash.new
      self.comm ||= OmfCommon::Comm.new(:xmpp)
      self.state ||= []
      self.groups ||= []
      self.events ||= []
      self.plan ||= Hashie::Mash.new
    end

    def id
      @name.nil? ? @id : "#{@name}-#{@id}"
    end

    def process_events
      self.events.find_all { |v| v[:callback] }.each do |event|
        if event[:trigger].call(self.state, self.plan)
          self.events.delete(event) if event[:consume_event]
          event[:callback].call
        end
      end
    end

    # Purely for backward compatibility
    class << self
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
