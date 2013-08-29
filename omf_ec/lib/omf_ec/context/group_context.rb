# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfEc::Context
  # Holds group configuration
  class GroupContext
    attr_accessor :group
    attr_accessor :guard
    attr_accessor :operation

    def initialize(opts)
      self.group = opts.delete(:group)
      self.guard = opts
      self
    end

    # Supports OEDL 6 syntax [] for setting FRCP guard
    #
    # @param [Hash] opts option hash which sets constraints
    #
    # @example Reduce throttle to zero for  all resources of type 'engine' from group 'A'
    #
    #   group('A') do |g|
    #     g.resources[type: 'engine'].throttle = 0
    #   end
    #
    def [](opts = {})
      self.guard.merge!(opts)
      self
    end

    # Calling standard methods or assignments will simply trigger sending a FRCP message
    #
    # @example OEDL
    #   # Will send FRCP CONFIGURE message
    #   g.resources[type: 'engine'].throttle = 0
    #
    #   # Will send FRCP REQUEST message
    #   g.resources[type: 'engine'].rpm
    #
    #   # Will send FRCP RELEASE message
    #   g.resources[type: 'engine'].release
    def method_missing(name, *args, &block)
      if name =~ /(.+)=/
        self.operation = :configure
        name = $1
      elsif name =~ /release/
        self.operation = :release
      else
        self.operation = :request
      end
      send_message(name, *args, &block)
    end

    # Send FRCP message
    #
    # @param [String] name of the property
    # @param [Object] value of the property, for configuring
    def send_message(name, value = nil, &block)
      if self.guard[:type]
        topic = self.group.resource_topic(self.guard[:type])
      else
        topic = self.group.topic
      end

      if topic.nil?
        if self.guard[:type]
          warn "Group '#{self.group.name}' has NO resources of type '#{self.guard[:type]}' ready. Could not send message."
        else
          warn "Group topic '#{self.group.name}' NOT subscribed. Could not send message."
        end
        return
      end


      case self.operation
      when :configure
        topic.configure({ name => value }, { guard: self.guard })
      when :request
        topic.request([:uid, :hrn, name], { guard: self.guard })
      when :release
        topics_to_release = OmfEc.experiment.state.find_all do |res_state|
          all_equal(self.guard.keys) do |k|
            res_state[k] == self.guard[k]
          end
        end

        topics_to_release.each do |res_state|
          OmfEc.subscribe_and_monitor(res_state.uid) do |child_topic|
            OmfEc.subscribe_and_monitor(self.group.id) do |group_topic|
              group_topic.release(child_topic) if child_topic
            end
          end
        end
      end
    end
  end
end
