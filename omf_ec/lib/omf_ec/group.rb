# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'monitor'

module OmfEc
  # Group instance used in experiment script
  #
  # @!attribute name [String] name of the resource
  # @!attribute id [String] pubsub topic id of the resource
  # @!attribute net_ifs [Array] network interfaces defined to be added to group
  # @!attribute members [Array] holding members to be added to group
  # @!attribute apps [Array] holding applications to be added to group
  class Group
    include MonitorMixin

    attr_accessor :name, :id, :net_ifs, :members, :app_contexts, :execs
    attr_reader :topic

    # @param [String] name name of the group
    # @param [Hash] opts
    def initialize(name, opts = {}, &block)
      super()
      self.name = name
      self.id = "#{OmfEc.experiment.id}.#{self.name}"
      # Add empty holders for members, network interfaces, and apps
      self.net_ifs = []
      self.members = {}
      self.app_contexts = []
      self.execs = []

      @resource_topics = {}

      OmfEc.subscribe_and_monitor(id, self, &block)
    end

    def address(suffix = nil)
      t_id = suffix ? "#{self.id}_#{suffix.to_s}" : self.id
      OmfCommon.comm.string_to_topic_address(t_id)
    end

    def associate_topic(topic)
      self.synchronize do
        @topic = topic
      end
    end

    def associate_resource_topic(name, res_topic)
      self.synchronize do
        @resource_topics[name] = res_topic
      end
    end

    def resource_topic(name)
      @resource_topics[name]
    end

    # Add existing resources to the group
    #
    # Resources to be added could be a list of resources, groups, or the mixture of both.
    def add_resource(*names)
      names.flatten!
      synchronize do
        # Recording membership first, used for ALL_UP event
        names.each do |name|
          if (g = OmfEc.experiment.group(name))# resource to add is a group
            @members.merge!(g.members)
          else
            OmfEc.experiment.nodes << name unless OmfEc.experiment.nodes.include?(name)
            @members[name] = nil
          end
        end
      end
    end

    # Create a set of new resources and add them to the group
    #
    # @param [String] name
    # @param [Hash] opts to be used to create new resources
    def create_resource(name, opts, &block)
      self.synchronize do
        raise ArgumentError, "Option :type is required for creating resource" if opts[:type].nil?

        # Make a deep copy of opts in case it contains structures of structures
        begin
          opts = Marshal.load ( Marshal.dump(opts.merge(hrn: name)))
        rescue => e
          raise "#{e.message} - Could not deep copy opts: '#{opts.inspect}'"
        end

        # Naming convention of child resource group
        #resource_group_name = "#{self.id}_#{opts[:type].to_s}"
        resource_group_name = self.address(opts[:type])

        OmfEc.subscribe_and_monitor(resource_group_name) do |res_group|
          associate_resource_topic(opts[:type].to_s, res_group)
          # Send create message to group
          r_type = opts.delete(:type)
          @topic.create(r_type, opts.merge(membership: resource_group_name))
        end
      end
    end

    # @return [OmfEc::Context::GroupContext]
    def resources
      OmfEc::Context::GroupContext.new(group: self)
    end

    # Add a new Prototype to the NodeSet associated with this Root Path
    #
    # - name = name of the Prototype to associate with the NodeSet of this Path
    # - params = optional, a Hash with the bindings to be passed on to the
    #
    # Prototype instance (see Prototype.instantiate)
    def addPrototype(name, params = nil)
      debug "Use prototype #{name}."
      p = OmfEc::Prototype[name]
      if p.nil?
        error "Unknown prototype '#{name}'"
        return
      end
      p.instantiate(self, params)
    end

    alias_method :prototype, :addPrototype

    include OmfEc::Backward::Group
  end
end
