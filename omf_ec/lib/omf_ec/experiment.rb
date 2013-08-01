# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'hashie'
require 'singleton'
require 'monitor'

module OmfEc
  # Experiment class to hold relevant state information
  #
  class Experiment
    include Singleton

    include MonitorMixin

    attr_accessor :name, :oml_uri, :app_definitions, :property, :cmdline_properties
    attr_reader :groups, :sub_groups, :state

    def initialize
      super
      @id = Time.now.utc.iso8601
      @state ||= [] #TODO: we need to keep history of all the events and not ovewrite them
      @groups ||= []
      @events ||= []
      @app_definitions ||= Hash.new
      @sub_groups ||= []
      @cmdline_properties ||= Hash.new
    end

    def property
      return ExperimentProperty
    end

    def add_property(name, value = nil, description = nil)
      override_value = @cmdline_properties[name.to_s.to_sym]
      value = override_value unless override_value.nil?
      ExperimentProperty.create(name, value, description)
    end

    def resource_state(address)
      @state.find { |v| v[:address].to_s == address.to_s }
    end

    alias_method :resource, :resource_state

    def resource_by_hrn(hrn)
      @state.find { |v| v[:hrn].to_s == hrn.to_s }
    end

    def add_or_update_resource_state(name, opts = {})
      self.synchronize do
        res = resource_state(name)
        if res
          opts.each do |key, value|
            if value.class == Array
              # Merge array values
              res[key] ||= []
              res[key] += value
              res[key].uniq!
            elsif value.kind_of? Hash
              # Merge hash values
              res[key] ||= {}
              res[key].merge(value)
            else
              # Overwrite otherwise
              res[key] = value
            end
          end
        else
          info "Newly discovered resource >> #{name}"
          res = Hashie::Mash.new({ address: name }).merge(opts)
          @state << res

          # Re send membership configure
          planned_groups = groups_by_res(res[:address])

          unless planned_groups.empty?
            OmfEc.subscribe_and_monitor(name) do |res|
              info "Config #{name} to join #{planned_groups.map(&:name).join(', ')}"
              res.configure(membership: planned_groups.map(&:address).join(', '))
            end
          end
        end
      end
    end

    alias_method :add_resource, :add_or_update_resource_state

    # Find all groups a given resource belongs to
    #
    def groups_by_res(res_addr)
      groups.find_all { |g| g.members.include?(res_addr) }
    end

    def sub_group(name)
      @sub_groups.find { |v| v == name }
    end

    def add_sub_group(name)
      self.synchronize do
        @sub_groups << name unless @sub_groups.include?(name)
      end
    end

    def group(name)
      groups.find { |v| v.name == name }
    end

    def add_group(group)
      self.synchronize do
        raise ArgumentError, "Expect Group object, got #{group.inspect}" unless group.kind_of? OmfEc::Group
        @groups << group unless group(group.name)
      end
    end

    def each_group(&block)
      if block
        groups.each { |g| block.call(g) }
      else
        groups
      end
    end

    def all_groups?(&block)
      !groups.empty? && groups.all? { |g| block ? block.call(g) : g }
    end

    def event(name)
      @events.find { |v| v[:name] == name }
    end

    def add_event(name, trigger)
      self.synchronize do
        raise RuntimeError, "Event '#{name}' has already been defined" if event(name)
        @events << { name: name, trigger: trigger }
      end
    end

    # Unique experiment id
    def id
      @name.nil? ? @id : "#{@name}-#{@id}"
    end

    # Parsing user defined events, checking conditions against internal state, and execute callbacks if triggered
    def process_events
      self.synchronize do
        @events.find_all { |v| v[:callbacks] && !v[:callbacks].empty? }.each do |event|
          if event[:trigger].call(@state)
            @events.delete(event) if event[:consume_event]
            info "Event triggered: '#{event[:name]}'"

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
        info "Experiment: #{OmfEc.experiment.id} finished"
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
