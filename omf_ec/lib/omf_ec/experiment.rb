require 'hashie'
require 'singleton'

module OmfEc
  # Experiment class to hold relevant state information
  #
  class Experiment
    include Singleton

    attr_accessor :name, :oml_uri, :app_definitions, :property
    attr_reader :groups, :sub_groups, :state

    def initialize
      @id = Time.now.utc.iso8601
      @property ||= Hashie::Mash.new
      @state ||= []
      @groups ||= []
      @events ||= []
      @app_definitions ||= Hash.new
      @sub_groups ||= []
    end

    def resource(id)
      @state.find { |v| v[:uid] == id }
    end

    def add_resource(name, opts = {})
      unless resource(name)
        @state << Hashie::Mash.new({ uid: name }.merge(opts))
      end
    end

    def sub_group(name)
      @sub_groups.find { |v| v == name }
    end

    def add_sub_group(name)
      @sub_groups << name unless @sub_groups.include?(name)
    end

    def group(name)
      groups.find { |v| v.name == name }
    end

    def add_group(group)
      raise ArgumentError, "Expect Group object, got #{group.inspect}" unless group.kind_of? OmfEc::Group
      @groups << group unless group(group.name)
    end

    def each_group(&block)
      groups.each { |g| block.call(g) } if block
    end

    def all_groups?(&block)
      !groups.empty? && groups.all? { |g| block ? block.call(g) : g }
    end

    def event(name)
      @events.find { |v| v[:name] == name }
    end

    def add_event(name, trigger)
      raise RuntimeError, "Event '#{name}' has been defined" if event(name)
      @events << { name: name, trigger: trigger }
    end

    # Unique experiment id
    def id
      @name.nil? ? @id : "#{@name}-#{@id}"
    end

    # Parsing user defined events, checking conditions against internal state, and execute callbacks if triggered
    def process_events
      EM.next_tick do
        @events.find_all { |v| v[:callbacks] && !v[:callbacks].empty? }.each do |event|
          if event[:trigger].call(@state)
            info "Event triggered: '#{event[:name]}'"
            @events.delete(event) if event[:consume_event]

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
        info "Exit in up to 15 seconds..."

        OmfCommon.eventloop.after(10) do
          info "Release applications and network interfaces"

          allGroups do |g|
            g.resources[type: 'application'].release
            g.resources[type: 'net'].release unless g.net_ifs.find_all { |v| v.conf[:type] == 'net' }.empty?
            g.resources[type: 'wlan'].release unless g.net_ifs.find_all { |v| v.conf[:type] == 'wlan' }.empty?
          end

          OmfCommon.eventloop.after(5) do
            OmfCommon.comm.disconnect
          end
        end
      end
    end
  end
end
