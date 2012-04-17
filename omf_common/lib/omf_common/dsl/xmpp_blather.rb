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

      def connect(username, password, server)
        jid = "#{username}@#{server}"

        client.setup(jid, password)

        when_ready do
          register(username, password) do |m|
            logger.warn m.inspect
            #client.close
            client.setup(jid, password)
            #client.run
          end
        end

        client.run
      end

      def disconnect
        # Delete all created pubsub nodes
        # unregister(username, password) do |m|
        client.close
        # end
      end

      def create_node(node, host, &block)
        pubsub.create_with_configuration(node, PUBSUB_CONFIGURE, host, &block)
      end

      def delete_node(node, host, &block)
        pusbub.delete(node, host, &block)
      end

      def subscribe(node, host, &block)
        pubsub.subscribe(node, nil, host, &block)
      end

      def unsubscribe(node, host)
        pubusub.subscriptions(host) do |m|
          m.subscribed.each do |s|
            pusbub.unsubscribe(node, nil, s.id, host)
          end
        end
      end

      def publish(node, message, host, &block)
        pubsub.publish(node, message, host, &block)
      end
    end
  end
end
