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
        MPConnection.inject(Time.now.to_f, jid, 'connect') if OmfCommon::Measure.enabled?
      end

      # Shut down XMPP connection
      def disconnect
        shutdown
        OmfCommon::DSL::Xmpp::MPConnection.inject(Time.now.to_f, jid, 'disconnect') if OmfCommon::Measure.enabled?
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
        MPSubscription.inject(Time.now.to_f, jid, 'join', topic) if OmfCommon::Measure.enabled?
      end

      # Un-subscribe all existing subscriptions from all pubsub topics.
      def unsubscribe
        pubsub.subscriptions(default_host) do |m|
          m[:subscribed] && m[:subscribed].each do |s|
            pubsub.unsubscribe(s[:node], nil, s[:subid], default_host, &callback_logging(__method__, s[:node], s[:subid]))
            MPSubscription.inject(Time.now.to_f, jid, 'leave', s[:node]) if OmfCommon::Measure.enabled?
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
        new_block = proc do |stanza|
          published_messages << OpenSSL::Digest::SHA1.new(message)
          block.call(stanza) if block
        end
        pubsub.publish(topic, message, default_host, &callback_logging(__method__, topic, &block))
        MPPublished.inject(Time.now.to_f, jid, topic, message.to_s.gsub("\n",'')) if OmfCommon::Measure.enabled?
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
        guard_block = proc do |event|
          passed = (event.items?) && (!event.delayed?) && event.items.first.payload &&
            !published_messages.include?(OpenSSL::Digest::SHA1.new(event.items.first.payload))

          MPReceived.inject(Time.now.to_f, jid, event.node, event.items.first.payload.to_s.gsub("\n",'')) if OmfCommon::Measure.enabled? && passed

          if additional_guard
            passed && additional_guard.call(event)
          else
            passed
          end
        end
        pubsub_event(guard_block, &callback_logging(__method__, &block))
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
