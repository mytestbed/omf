require 'blather/client/dsl'

module OmfCommon
  module DSL
    module Xmpp
      include Blather::DSL

      HOST_PREFIX = 'pubsub'

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

      # Shut down XMPP connection
      def disconnect
        shutdown
      end

      # Create a new pubsub topic with additional configuration
      #
      # @param [String] topic Pubsub topic name
      def create_topic(topic, &block)
        pubsub.create(topic, default_host, PUBSUB_CONFIGURE, &callback_logging(__method__, topic, &block))
      end

      # Delete a pubsub topic
      #
      # @param [String] topic Pubsub topic name
      def delete_topic(topic, &block)
        pubsub.delete(topic, default_host, &callback_logging(__method__, topic, &block))
      end

      # Subscribe to a pubsub topic
      #
      # @param [String] topic Pubsub topic name
      def subscribe(topic, &block)
        pubsub.subscribe(topic, nil, default_host, &callback_logging(__method__, topic, &block))
      end

      # Un-subscribe all existing subscriptions from all pubsub topics.
      def unsubscribe
        pubsub.subscriptions(default_host) do |m|
          m[:subscribed] && m[:subscribed].each do |s|
            pubsub.unsubscribe(s[:node], nil, s[:subid], default_host, &callback_logging(__method__, s[:node], s[:subid]))
          end
        end
      end

      def affiliations(&block)
        pubsub.affiliations(default_host, &callback_logging(__method__, &block))
      end

      # Publish to a pubsub topic
      #
      # @param [String] topic Pubsub topic name
      # @param [String] message Any XML fragment to be sent as payload
      def publish(topic, message, &block)
        raise StandardError, "Invalid message" unless message.valid?
        pubsub.publish(topic, message, default_host, &callback_logging(__method__, topic, message.operation, &block))
      end

      # Generate OMF related message
      %w(create configure request inform release).each do |m_name|
        define_method("#{m_name}_message") do |*args, &block|
          if block
            Message.send(m_name, *args, &block)
          elsif args[0].kind_of? Array
            Message.send(m_name) do |v|
              args[0].each do |opt|
                if opt.kind_of? Hash
                  opt.each_pair do |key, value|
                    if value.kind_of? Hash
                      v.property(key) { |p| value.each_pair { |p_key, p_value| p.element(p_key, p_value) } }
                    else
                      v.property(key, value)
                    end
                  end
                else
                  v.property(opt)
                end
              end
            end
          end
        end
      end

      # Event machine related method delegation
      %w(add_timer add_periodic_timer).each do |m_name|
        define_method(m_name) do |*args, &block|
          EM.send(m_name, *args, &block)
        end
      end

      %w(created status released failed event).each do |inform_type|
        define_method("on_#{inform_type}_message") do |*args, &message_block|
          context_id = args[0].context_id if args[0]
          event_block = proc do |event|
            message_block.call(Message.parse(event.items.first.payload))
          end
          guard_block = proc do |event|
            (event.items?) && (!event.delayed?) &&
              event.items.first.payload &&
              (omf_message = Message.parse(event.items.first.payload)) &&
              omf_message.operation == :inform &&
              omf_message.read_content(:inform_type) == inform_type.upcase &&
              (context_id ? (omf_message.context_id == context_id) : true)
          end
          pubsub_event(guard_block, &callback_logging(__method__, &event_block))
        end
      end

      # Event callback for pubsub topic event(item published)
      #
      def topic_event(*args, &block)
        pubsub_event(:items?, *args, &callback_logging(__method__, &block))
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

      def default_host
        "#{HOST_PREFIX}.#{client.jid.domain}"
      end
    end
  end
end
