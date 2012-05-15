require 'blather/client/dsl'
require 'omf_common/core_ext/blather/dsl'
require 'omf_common/core_ext/blather/dsl/pubsub'
require 'omf_common/core_ext/blather/stanza/registration'

module OmfCommon
  module DSL
    module XmppBlather
      include Blather::DSL

      PUBSUB_CONFIGURE = Blather::Stanza::X.new({
        :type => :submit,
        :fields => [
          { :var => "FORM_TYPE", :type => 'hidden', :value => "http://jabber.org/protocol/pubsub#node_config" },
          { :var => "pubsub#persist_items", :value => "0" },
          { :var => "pubsub#max_items", :value => "0" },
          { :var => "pubsub#notify_retract",  :value => "0" },
          { :var => "pubsub#publish_model", :value => "open" }]
      })

      # Set up XMPP options and start the Eventmachine, connect to XMPP server
      #
      def connect(username, password, server)
        jid = "#{username}@#{server}"
        client.setup(jid, password)
        client.run
      end

      # Shut down XMPP connection, clean up pubsub nodes if necessary
      #
      # @param [String] host Host represents the pubsub address, e.g. pubsub.norbit.npc.nicta.com.au
      def disconnect(host)
        pubsub.affiliations(host) do |affs|
          # We don't care if server has user tune support
          affs[:owner].delete_if { |item| item == "http://jabber.org/protocol/tune" } if affs[:owner]
          shutdown if affs[:owner].nil? || affs[:owner].empty?
          affs[:owner] && affs[:owner].each do |item|
            delete_node(item, host) do |m|
              pubsub.affiliations(host) do |affs|
                affs[:owner].delete_if { |item| item == "http://jabber.org/protocol/tune" } if affs[:owner]
                shutdown if affs[:owner].nil? || affs[:owner].empty?
              end
            end
          end
        end
      end

      # Create a new pubsub node with additional configuration
      #
      # @param [String] node Pubsub node name
      # @param [String] host Pubsub host address
      def create_node(node, host, &block)
        pubsub.create_with_configuration(node, PUBSUB_CONFIGURE, host, &callback_logging(__method__, node, &block))
      end

      # Delete a pubsub node
      #
      # @param [String] node Pubsub node name
      # @param [String] host Pubsub host address
      def delete_node(node, host, &block)
        pubsub.delete(node, host, &callback_logging(__method__, node, &block))
      end

      # Subscribe to a pubsub node
      #
      # @param [String] node Pubsub node name
      # @param [String] host Pubsub host address
      def subscribe(node, host, &block)
        pubsub.subscribe(node, nil, host, &callback_logging(__method__, node, &block))
      end

      # Un-subscribe all existing subscriptions from all pubsub nodes.
      #
      # @param [String] node Pubsub node name
      # @param [String] host Pubsub host address
      def unsubscribe(host)
        pubsub.subscriptions(host) do |m|
          m[:subscribed] && m[:subscribed].each do |s|
            pubsub.unsubscribe(s[:node], nil, s[:subid], host, &callback_logging(__method__, s[:node], s[:subid]))
          end
        end
      end

      # Publish to a pubsub node
      #
      # @param [String] node Pubsub node name
      # @param [String] message Any XML fragment to be sent as payload
      # @param [String] host Pubsub host address
      def publish(node, message, host, &block)
        pubsub.publish(node, message, host, &callback_logging(__method__, node, message.operation, &block))
      end

      # Event callback for pubsub node event(created, deleted)
      #
      def node_event(*args, &block)
        pubsub_event(:items, *args, &callback_logging(__method__, &block))
      end

      # Event callback for pubsub items event(item published)
      #
      def node_item_event(*args, &block)
        pubsub_event(:items, :node, *args, &callback_logging(__method__, &block))
      end

      private

      # Provide a new block wrap to automatically log errors
      def callback_logging(*args, &block)
        m = args.empty? ? "OPERATION" : args.map {|v| v.to_s.upcase }.join(" ")
        proc do |callback|
          logger.error callback if callback.respond_to?(:error?) && callback.error?
          logger.debug "#{m} SUCCEED" if callback.respond_to?(:result?) && callback.result?
          block.call(callback) if block
        end
      end
    end
  end
end
