module OmfEc
  class NetContext
    attr_accessor :group
    attr_accessor :conf

    def initialize(opts)
      self.group = opts.delete(:group)
      self.conf = opts
      self
    end

    def method_missing(name, *args, &block)
      if name =~ /(.+)=/
        net_prop = $1.to_sym
        net_prop = case net_prop
                   when :type then :hw_mode
                   when :ip then :ip_addr
                   else
                     net_prop
                   end
        self.conf.merge!(net_prop => args[0])
      else
        super
      end
    end
  end
end
