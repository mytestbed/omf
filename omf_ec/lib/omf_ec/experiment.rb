require 'hashie'
require 'singleton'

module OmfEc
  class Experiment
    include Singleton

    attr_reader :property
    attr_reader :state
    attr_accessor :comm
    attr_accessor :groups
    attr_accessor :events

    def initialize
      self.property ||= Hashie::Mash.new
      self.comm ||= OmfCommon::Comm.new(:xmpp)
      self.state ||= []
      self.groups ||= []
      self.events ||= []
    end

    def process_events
      self.events.find_all { |v| v[:callback] }.each do |event|
        if event[:trigger].call
          event[:callback].call
          self.events.delete(event) if event[:consume_event]
        end
      end
    end

    # Purely for backward compatibility
    class << self
      def done
        self.comm.disconnect
      end
    end
  end
end
