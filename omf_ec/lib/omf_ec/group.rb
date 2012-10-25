require 'omf_ec/experiment'

module OmfEc
  class Group
    attr_accessor :name

    def initialize(name)
      self.name = name
    end

    def comm
      Experiment.instance.comm
    end

    def add_resource(name, &block)
      comm.subscribe(name) do |m|
        unless m.error?
          c = comm.configure_message(self.name) do |m|
            m.property(:membership, self.name)
          end
          c.publish name
          c.on_inform_status do |i|
            info "#{name} added"
            block.call if block
          end
        end
      end
    end

    def create_resource(name, opts, &block)
      # We create another group topic for new resoruces
      opts = opts.merge(hrn: name)

      # Naming convention of child resource group
      resource_group_name = "#{self.name}_#{opts[:type]}_#{opts[:hrn]}"

      comm.subscribe(resource_group_name, true) do |m|
        unless m.error?
          c = comm.create_message(self.name) do |m|
            m.property(:type, opts[:type])
            m.property(:membership, resource_group_name)
          end
          c.publish self.name
          c.on_inform_created do |i|
            info "#{opts[:type]} #{i.resource_id} created"
            block.call if block
          end
        end
      end
    end

    def resources
    end

    def request(group, *properties)
      r = comm.request_message(group) do |m|
        properties.each do |p|
          m.property(p)
        end
        m.property(:uid)
      end
      r.publish group
      r.on_inform_status do |i|
        info i
      end
    end

    def release(group)
      r = comm.request_message(group) do |m|
        m.property(:uid)
      end
      r.publish group
      r.on_inform_status do |i|
        uid = i.read_property(:uid)
        info "Going to release #{uid}"
        r_m = comm.release_message { |m| m.element('resource_id', uid) }
        r_m.publish 'world'
        r_m.on_inform_released do |m|
          info m
        end
      end
    end
  end
end
