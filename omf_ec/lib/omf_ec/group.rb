require 'securerandom'

module OmfEc
  # Group instance used in experiment script
  #
  # @!attribute name [String] name of the resource
  # @!attribute id [String] pubsub topic id of the resource
  # @!attribute net_ifs [Array] network interfaces defined to be added to group
  # @!attribute members [Array] holding members to be added to group
  # @!attribute apps [Array] holding applications to be added to group
  class Group
    attr_accessor :name, :id, :net_ifs, :members, :app_contexts

    # @param [String] name name of the group
    # @param [Hash] opts
    # @option opts [Boolean] :unique Should the group be unique or not, default is true
    def initialize(name, opts = {})
      @opts = {unique: true}.merge!(opts)
      self.name = name
      self.id = @opts[:unique] ? SecureRandom.uuid : self.name
      # Add empty holders for members, network interfaces, and apps
      self.net_ifs = []
      self.members = []
      self.app_contexts = []
    end

    # Add existing resources to the group
    #
    # Resources to be added could be a list of resources, groups, or the mixture of both.
    def add_resource(*names)
      names.each do |name|
        # resource to add is a group
        if OmfEc.exp.groups.any? { |v| v.name == name }
          self.add_resource(*group(name).members.uniq)
        else
          OmfEc.comm.subscribe(name) do |m|
            unless m.error?
              # resource with uid: name is available
              unless OmfEc.exp.state.any? { |v| v[:uid] == name }
                OmfEc.exp.state << { uid: name }
              end

              r = OmfEc.comm.get_topic(name)

              r.on_message lambda {|m| m.operation == :inform && m.read_content('inform_type') == 'STATUS' && m.context_id.nil? } do |i|
                r = OmfEc.exp.state.find { |v| v[:uid] == i.read_property(:uid) }
                unless r.nil?
                  i.each_property do |p|
                    key = p.attr('key').to_sym
                    r[key] = i.read_property(key)
                  end
                end
                Experiment.instance.process_events
              end

              # Receive failed inform message
              r.on_message lambda {|m| m.operation == :inform && m.read_content('inform_type') == 'CREATION_CREATION_FAILED' && m.context_id.nil? } do |i|
                warn "RC reports failure: '#{i.read_content("reason")}'"
              end

              c = OmfEc.comm.configure_message(self.id) do |m|
                m.property(:membership, self.id)
              end

              c.publish name

              c.on_inform_status do |i|
                r = OmfEc.exp.state.find { |v| v[:uid] == name }
                r[:membership] = i.read_property(:membership)
                Experiment.instance.process_events
              end

              c.on_inform_creation_failed do |i|
                warn "RC reports failure: '#{i.read_content("reason")}'"
              end
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

      # Make a deep copy of opts in case it contains structures of structures
      begin
        opts = Marshal.load ( Marshal.dump(opts.merge(hrn: name)))
      rescue Exception => e
        raise "#{e.message} - Could not deep copy opts: '#{opts.inspect}'"
      end

      # Naming convention of child resource group
      resource_group_name = "#{self.id}_#{opts[:type]}"


      unless OmfEc.exp.sub_groups.include?(resource_group_name)
        OmfEc.exp.sub_groups << resource_group_name

        rg = OmfEc.comm.get_topic(resource_group_name)
        # Receive  status inform message
        rg.on_message lambda {|m| m.operation == :inform && m.read_content('inform_type') == 'STATUS' && m.context_id.nil? } do |i|
          r = OmfEc.exp.state.find { |v| v[:uid] == i.read_property(:uid) }
          unless r.nil?
            if i.read_property("status_type") == 'APP_EVENT'
              info "APP_EVENT #{i.read_property('event')} "+
                "from app #{i.read_property("app")} - msg: #{i.read_property("msg")}"
            end
            i.each_property do |p|
              r[p.attr('key').to_sym] = p.content.ducktype
            end
          end
          Experiment.instance.process_events
        end

        # Receive failed inform message
        rg.on_message lambda {|m| m.operation == :inform && m.read_content('inform_type') == 'CREATION_CREATION_FAILED' && m.context_id.nil? } do |i|
          warn "RC reports failure: '#{i.read_content("reason")}'"
        end
      end

      # We create another group topic for new resouce
      OmfEc.comm.subscribe(resource_group_name, create_if_non_existent: true) do |m|
        unless m.error?

          c = OmfEc.comm.create_message(self.id) do |m|
            m.property(:membership, resource_group_name)
            opts.each_pair do |k, v|
              m.property(k, v)
            end
          end

          c.publish self.id

          c.on_inform_creation_ok do |i|
            info "#{opts[:type]} #{i.resource_id} created"
            OmfEc.exp.state << { uid: i.resource_id, type: opts[:type], hrn: name, membership: [resource_group_name]}
            block.call if block
            Experiment.instance.process_events
          end

          c.on_inform_creation_failed do |i|
            warn "RC reports failure: '#{i.read_content("reason")}'"
          end
        end
      end
    end

    # @return [OmfEc::Context::GroupContext]
    def resources
      OmfEc::Context::GroupContext.new(group: self.id)
    end

    include OmfEc::Backward::Group
  end
end
