module OmfEc::Context
  class GroupContext
    attr_accessor :group
    attr_accessor :guard
    attr_accessor :operation

    def initialize(opts)
      self.group = opts.delete(:group)
      self.guard = opts
      self
    end

    def [](opts = {})
      self.guard.merge!(opts)
      self
    end

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

    def send_message(name, value = nil, &block)
      if self.guard[:type]
        topic = self.group.resource_topic(self.guard[:type])
      else
        topic = self.group.topic
      end

      # if release, we need to request resource ids first
      #op_name = self.operation == :release ? "request" : self.operation

      case self.operation
      when :configure
        topic.configure({ name => value })
      when :request
        topic.request([:uid, :hrn, name])
      when :release
        #topic.release
      end

      #o_m = OmfCommon.comm.__send__(op_name, send_to) do |m|
        #m.element(:guard) do |g|
        #  self.guard.each_pair do |k, v|
        #    g.property(k, v)
        #  end
        #end

      #o_m.on_inform_status do |i|
        #if self.operation == :release
        #  uid = i.read_property(:uid)
        #  info "Going to release #{uid}"
        #  release_m = OmfCommon.comm.release_message(self.group) { |m| m.element('resource_id', uid) }

        #  release_m.publish self.group

        #  release_m.on_inform_released do |m|
        #    info "#{m.resource_id} released"
        #    r = OmfEc.experiment.state.find { |v| v[:uid] == m.resource_id }
        #    r[:released] = true unless r.nil?
        #    block.call if block
        #    Experiment.instance.process_events
        #  end
        #end

        #r = OmfEc.experiment.state.find { |v| v[:uid] == i.read_property(:uid) }
        #unless r.nil?
        #  i.each_property do |p|
        #    p_key = p.attr('key').to_sym
        #    r[p_key] = i.read_property(p_key)
        #  end
        #end
        #Experiment.instance.process_events
      #end

      #o_m.on_inform_creation_failed do |i|
      #  warn "RC reports failure: '#{i.read_content("reason")}'"
      #end
    end
  end
end
