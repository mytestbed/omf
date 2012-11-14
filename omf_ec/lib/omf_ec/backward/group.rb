module OmfEc
  module Backward
    module Group
      # The following are ODEL 5 methods

      # Create an application for the group and start it
      #
      def exec(name)
        create_resource(name, type: 'application', binary_path: name)
        # FIXME should not assume its ready in 1 second
        after 1.second do
          resources[type: 'application', name: name].state = :run
        end
      end

      # @example
      #   group('actor') do |g|
      #     g.net.w0.ip = '0.0.0.0'
      #     g.net.e0.ip = '0.0.0.1'
      #   end
      def net
        self.net_ifs ||= []
        self
        #g.create_resource('wlan0', type: 'wlan')
        #g.resources[name: 'wlan0']
      end

      def method_missing(name, *args, &block)
        if name =~ /w(\d+)/
          net = self.net_ifs.find { |v| v.conf[:hrn] == "wlan#{$1}" }
          if net.nil?
            net = OmfEc::NetContext.new(:group => self.name, :type => 'wlan', :hrn => "wlan#{$1}", :index => $1)
            self.net_ifs << net
          end
          net
        elsif name =~ /e(\d+)/
          net = self.net_ifs.find { |v| v.conf[:hrn] == "eth#{$1}" }
          if net.nil?
            net = OmfEc::NetContext.new(:group => self.name, :type => 'net', :hrn => "eth#{$1}", :index => $1)
            self.net_ifs << net
          end
          net
        else
          super
        end
      end

    end
  end
end
