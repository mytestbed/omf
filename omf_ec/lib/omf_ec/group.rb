# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'monitor'
require 'omf_ec/group_ext'

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
    extend GroupExt

    attr_accessor :name, :id, :net_ifs, :members, :app_contexts, :execs
    attr_reader :topic, :g_aliases

    fwd_method_to_aliases :startApplications, :stopApplications, :startApplication

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
      # To record group 2 group relationship
      @g_aliases = []

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

      # When names is array of resource hash
      if !names.empty? && names[0].kind_of?(Hash)
        names.map! { |v| v['omf_id'] if v['type'] == 'node' }.compact!
      end

      synchronize do
        # Recording membership first, used for ALL_UP event
        names.each do |name|
          if (g = OmfEc.experiment.group(name))# resource to add is a group
            @members.merge!(g.members)
            @g_aliases << g
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
          @topic.create(r_type, opts.merge(membership: resource_group_name),
                        assert: OmfEc.experiment.assertion)
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

    def resource_group(type)
      "#{self.id}_#{type.to_s}"
    end

    # Create an application for the group and start it
    #
    def exec(command)
      name = SecureRandom.uuid

      self.synchronize do
        self.execs << name
      end
      create_resource(name, type: 'application', binary_path: command)

      e_name = "#{self.name}_application_#{name}_created"

      resource_group_name = self.address("application")

      def_event e_name do |state|
        state.find_all { |v| v[:hrn] == name && v[:membership] && v[:membership].include?(resource_group_name)}.size >= self.members.values.sort.uniq.size
      end

      on_event e_name do
        resources[type: 'application', name: name].state = :running
      end
    end

    # Start ONE application by name
    def startApplication(app_name)
      if self.app_contexts.find { |v| v.name == app_name }
        resources[type: 'application', name: app_name].state = :running
      else
        warn "No application with name '#{app_name}' defined in group #{self.name}. Nothing to start"
      end
    end

    # Start ALL applications in the group
    def startApplications
      if self.app_contexts.empty?
        warn "No applications defined in group #{self.name}. Nothing to start"
      else
        resources[type: 'application'].state = :running
      end
    end

    # Stop ALL applications in the group
    def stopApplications
      if self.app_contexts.empty?
        warn "No applications defined in group #{self.name}. Nothing to stop"
      else
        resources[type: 'application'].state = :stopped
      end
    end

    def addApplication(name, location = nil, &block)
      app_cxt = OmfEc::Context::AppContext.new(name,location,self)
      block.call(app_cxt) if block
      self.app_contexts << app_cxt
    end

    # @example
    #   group('actor', 'node1', 'node2') do |g|
    #     g.net.w0.ip = '0.0.0.0'
    #     g.net.e0.ip = '0.0.0.1'
    #   end
    def net
      self.net_ifs ||= []
      self
    end

    def method_missing(name, *args, &block)
      if name =~ /w(\d+)/
        net = self.net_ifs.find { |v| v.conf[:if_name] == "wlan#{$1}" }
        if net.nil?
          net = OmfEc::Context::NetContext.new(:type => 'wlan', :if_name => "wlan#{$1}", :index => $1)
          self.net_ifs << net
        end
        net
      elsif name =~ /e(\d+)/
        net = self.net_ifs.find { |v| v.conf[:if_name] == "eth#{$1}" }
        if net.nil?
          net = OmfEc::Context::NetContext.new(:type => 'net', :if_name => "eth#{$1}", :index => $1)
          self.net_ifs << net
        end
        net
      else
        super
      end
    end
  end
end
