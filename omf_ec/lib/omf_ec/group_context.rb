module OmfEc
  class GroupContext
    attr_accessor :group
    attr_accessor :guard
    attr_accessor :operation

    def initialize(opts)
      self.group = opts.delete(:group)
      self.guard = opts
      self
    end

    def exp
      Experiment.instance
    end

    def comm
      Experiment.instance.comm
    end

    def method_missing(name, *args, &block)
      if name =~ /(.+)=/
        self.operation = :configure
        name = $1
      else
        self.operation = :request
      end
      send_message(name, *args, &block)
    end

    def send_message(name, value = nil, &block)
      send_to = self.group
      send_to = send_to + "_#{self.guard[:type]}" if self.guard[:type]

      o_m = comm.__send__("#{self.operation}_message", send_to) do |m|
        m.element(:guard) do |g|
          self.guard.each_pair do |k, v|
            g.element(k, v)
          end
        end
        m.property(name, value)

        if self.operation == :request
          m.property(:uid)
          m.property(:hrn)
        end
      end

      o_m.publish send_to

      o_m.on_inform_status do |i|
        r = exp.state.find { |v| v[:uid] == i.read_property(:uid) }
        unless r.nil?
          i.each_property do |p|
            r[p.attr('key').to_sym] = p.content.ducktype
          end
        end
        Experiment.instance.process_events
      end
    end
  end
end
