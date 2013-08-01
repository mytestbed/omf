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
    # @option opts [Boolean] :unique Should the group be unique or not, default is true
    def initialize(name, opts = {}, &block)
      super()
      @opts = {unique: true}.merge!(opts)
      self.name = name
      self.id = @opts[:unique] ? SecureRandom.uuid : self.name
      # Add empty holders for members, network interfaces, and apps
      self.net_ifs = []
      self.members = []
      self.app_contexts = []
      self.execs = []

      @resource_topics = {}

      OmfEc.subscribe_and_monitor(id, self, &block)
    end

    def address(suffix = nil)
      t_id = suffix ? "#{self.id}_#{suffix.to_s}" : self.id
      "#{OmfCommon.comm.conn_info[:proto]}://#{t_id}@#{OmfCommon.comm.conn_info[:domain]}"
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
      self.synchronize do
        # Recording membership first, used for ALL_UP event
        names.each do |name|
          g = OmfEc.experiment.group(name)
          if g # resource to add is a group
            @members += g.members
            self.add_resource(*g.members.uniq)
          else
            OmfEc.subscribe_and_monitor(name) do |res|
              @members << res.address
              info "Config #{name} to join #{self.name}"
              res.configure(membership: self.address)
            end
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

    include OmfEc::Backward::Group
  end
end
