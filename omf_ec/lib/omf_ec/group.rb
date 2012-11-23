module OmfEc
  class Group
    attr_accessor :name
    attr_accessor :net_ifs

    def initialize(name)
      self.name = name
    end

    def add_resource(*names)
      names.each do |name|
        OmfEc.comm.subscribe(name) do |m|
          unless m.error?
            # resource with uid: name is available
            OmfEc.exp.state << { uid: name } unless OmfEc.exp.state.find { |v| v[:uid] == name }

            if OmfEc.exp.groups.include?(name)
              group(name).resources.membership = self.name
            else
              c = OmfEc.comm.configure_message(self.name) do |m|
                m.property(:membership, self.name)
              end
              c.publish name
              c.on_inform_status do |i|
                info "#{name} added to #{self.name}"
                r = OmfEc.exp.state.find { |v| v[:uid] == name }
                r[:membership] = i.read_property(:membership)
                Experiment.instance.process_events
              end
              c.on_inform_failed do |i|
                warn "RC reports failure: '#{i.read_content("reason")}'"
              end
            end
          end
        end
      end
    end

    def create_resource(name, opts, &block)
      # We create another group topic for new resoruces
      opts = opts.merge(hrn: name)

      # Naming convention of child resource group
      resource_group_name = "#{self.name}_#{opts[:type]}"

      OmfEc.comm.subscribe(resource_group_name, create_if_non_existent: true) do |m|
        unless m.error?
          c = OmfEc.comm.create_message(self.name) do |m|
            m.property(:membership, resource_group_name)
            opts.each_pair do |k, v|
              m.property(k, v)
            end
          end
          c.publish self.name
          c.on_inform_created do |i|
            info "#{opts[:type]} #{i.resource_id} created"
            OmfEc.exp.state << { uid: i.resource_id, type: opts[:type] }
            block.call if block
            Experiment.instance.process_events
          end
          c.on_inform_failed do |i|
            warn "RC reports failure: '#{i.read_content("reason")}'"
          end

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
          rg.on_message lambda {|m| m.operation == :inform && m.read_content('inform_type') == 'FAILED' && m.context_id.nil? } do |i|
            warn "RC reports failure: '#{i.read_content("reason")}'"
          end
        end
      end
    end

    def resources
      OmfEc::Context::GroupContext.new(group: self.name)
    end

    include OmfEc::Backward::Group
  end
end
