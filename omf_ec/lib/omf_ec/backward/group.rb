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

      def startApplications
        resources[type: 'application'].state = :run
      end

      def stopApplications
        resources[type: 'application'].state = :stop
      end

      def addApplication(name, &block)
        # app_cxt = OmfEc::Context::AppContext.new(name)
        # block.call(app_cxt) if block
        # puts "TDB A"
        # puts app_cxt.inspect
        # puts "TDB B"
        # create_resource(name, :type => 'application', binary_path: name)
        # puts "TDB C"
        # # Then should just create the resource with app.conf
        # # create_resource(name, app.conf)
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
          net = self.net_ifs.find { |v| v.conf[:hrn] == "wlan#{$1}" }
          if net.nil?
            net = OmfEc::Context::NetContext.new(:type => 'wlan', :hrn => "wlan#{$1}", :index => $1)
            self.net_ifs << net
          end
          net
        elsif name =~ /e(\d+)/
          net = self.net_ifs.find { |v| v.conf[:hrn] == "eth#{$1}" }
          if net.nil?
            net = OmfEc::Context::NetContext.new(:type => 'net', :hrn => "eth#{$1}", :index => $1)
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
