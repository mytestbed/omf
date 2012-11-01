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

    def method_missing(name, *args, &block)
      if name =~ /(.+)=/
        self.operation = :configure
        name = $1
      else
        self.operation = :request
      end
      puts build_message(name, *args)
    end

    def build_message(name, value = nil)
      OmfCommon::Message.send(self.operation) do |m|
        m.element(:guard) do |g|
          self.guard.each_pair do |k, v|
            g.element(k, v)
          end
        end
        m.property(name, value)
      end
    end
  end
end
