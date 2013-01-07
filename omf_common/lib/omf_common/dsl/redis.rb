
module OmfCommon
  module DSL
    module Redis
      # Set up XMPP options and start the Eventmachine, connect to XMPP server
      #
      def connect(username, password, server)
      end

      # Shut down XMPP connection
      def disconnect(opts = {})
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
      # @param [Hash] opts
      # @option opts [Boolean] :create_if_non_existent create the topic if non-existent, use this option with caution
      def subscribe(topic, opts = {}, &block)
      end

      # Un-subscribe all existing subscriptions from all pubsub topics.
      def unsubscribe
      end

      def affiliations(&block)
        pubsub.affiliations(default_host, &callback_logging(__method__, &block))
      end

      # Publish to a pubsub topic
      #
      # @param [String] topic Pubsub topic name
      # @param [String] message Any XML fragment to be sent as payload
      def publish(topic, message, &block)
      end

      # Event machine related method delegation
      %w(add_timer add_periodic_timer).each do |m_name|
        define_method(m_name) do |*args, &block|
          EM.send(m_name, *args, &block)
        end
      end

      # Event callback for pubsub topic event(item published)
      #
      def topic_event(additional_guard = nil, &block)
        raise "What is that used for?"
        
      end

      
    end # module Redis
  end
end
