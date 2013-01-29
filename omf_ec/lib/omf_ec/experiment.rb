require 'hashie'
require 'singleton'

module OmfEc
  # Experiment class to hold relevant state information
  #
  class Experiment
    include Singleton

    attr_accessor :property,:state, :comm, :groups, :events, :name, :app_definitions, :sub_groups, :oml_uri

    def initialize
      @id = Time.now.utc.iso8601
      self.property ||= Hashie::Mash.new
      self.comm ||= OmfCommon.comm
      self.state ||= []
      self.groups ||= []
      self.events ||= []
      self.app_definitions ||= Hash.new
      self.sub_groups ||= []
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
        info "Exit in up to 20 seconds..."

        OmfCommon.eventloop.after(10) do
          info "Release applications and network interfaces"

          allGroups do |g|
            g.resources[type: 'application'].release
            g.resources[type: 'net'].release unless g.net_ifs.find_all { |v| v.conf[:type] == 'net' }.empty?
            g.resources[type: 'wlan'].release unless g.net_ifs.find_all { |v| v.conf[:type] == 'wlan' }.empty?
          end

          OmfCommon.eventloop.after(5) do
            OmfCommon.comm.disconnect(delete_affiliations: true)

            OmfCommon.eventloop.after(5) do
              OmfCommon.comm.disconnect
            end
          end
        end
      end
    end
  end
end
