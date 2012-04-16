require "omf_common/core_ext/blather/dsl"
require "omf_common/core_ext/blather/dsl/pubsub"
require "omf_common/core_ext/blather/stanza/registration"

module OmfCommon
  module DSL
    module XMPPBlather
      extend Blather::DSL

      PUBSUB_CONFIGURE = Blather::Stanza::X.new({
        :type => :submit,
        :fields => [
          { :var => "FORM_TYPE", :type => 'hidden', :value => "http://jabber.org/protocol/pubsub#node_config" },
          { :var => "pubsub#persist_items", :value => "0" },
          { :var => "pubsub#max_items", :value => "0" },
          { :var => "pubsub#notify_retract",  :value => "0" },
          { :var => "pubsub#publish_model", :value => "open" }]
      })


      class << self
        def connect(username, password, server)
          self.jid = "#{username}@#{server}"

          register(username, password) do |m|
            client.setup(jid, password)
            client.run
          end
        end

        def disconnect
          # Delete all created pubsub nodes
          unregister(username, password) do |m|
            client.close
          end
        end

        def create_node(name, host)
          pubsub.create_configure(name, PUBSUB_CONFIGURE, host)
        end

        def delete_node(name, host)
          pusbub.delete(name, host)
        end

        def subscribe(node, host)
          pubsub.subscribe(node, nil, host)
        end

        def unsubscribe(node, host)
          pubusub.subscriptions(host) do |m|
            m.subscribed.each do |s|
              pusbub.unsubscribe(node, nil, s.id, host)
            end
          end
        end

        def publish(node, message, host)
          pubsub.publish(node, message, host)
        end
      end

      when_ready do
        logger.info "Connected!"
      end
    end
  end
end
