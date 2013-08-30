# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'

module OmfEc
  module Backward
    module Group
      # The following are ODEL 5 methods

      def resource_group(type)
        "#{self.id}_#{type.to_s}"
      end

      # Create an application for the group and start it
      #
      def exec(name)
        self.synchronize do
          self.execs << name
        end
        create_resource(name, type: 'application', binary_path: name)

        e_uid = SecureRandom.uuid
        e_name = "#{self.name}_application_#{name}_created_#{e_uid}"

        resource_group_name = self.address("application")

        def_event e_name do |state|
          state.find_all { |v| v[:hrn] == name && v[:membership] && v[:membership].include?(resource_group_name)}.size >= self.members.values.sort.uniq.size
        end

        on_event e_name do
          resources[type: 'application', name: name].state = :running
        end
      end

      def startApplications
        if self.app_contexts.empty?
          warn "No applications defined in group #{self.name}. Nothing to start"
        else
          resources[type: 'application'].state = :running
        end
      end

      def stopApplications
        if self.app_contexts.empty?
          warn "No applications defined in group #{self.name}. Nothing to stop"
        else
          resources[type: 'application'].state = :stopped
        end
      end

      def addApplication(name, &block)
        app_cxt = OmfEc::Context::AppContext.new(name,self)
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
end
