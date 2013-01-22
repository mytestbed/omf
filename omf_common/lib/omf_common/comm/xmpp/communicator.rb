require 'blather/client/dsl'

module OmfCommon
class Comm
  class XMPP
    class Communicator < OmfCommon::Comm
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
      def init(opts = {})
        username = opts[:username]
        password = opts[:password]
        server = opts[:server]
        connect(username, password, server)
      end

      # Set up XMPP options and start the Eventmachine, connect to XMPP server
      #
      def connect(username, password, server)
        jid = "#{username}@#{server}"
        client.setup(jid, password)
        client.run
        MPConnection.inject(Time.now.to_f, jid, 'connect') if OmfCommon::Measure.enabled?
      end

      # Shut down XMPP connection
      def disconnect(opts = {})
        if opts[:delete_affiliations]
          affiliations do |a|
            # owner means topics created, owned
            owner_topics = a[:owner] ? a[:owner].size : 0
            # none means... topics subscribed to
            none_topics = a[:none] ? a[:none].size : 0

            if none_topics > 0
              info "Unsubscribing #{none_topics} pubsub topic(s)"
              unsubscribe
            end

            if owner_topics > 0
              info "Deleting #{owner_topics} pubsub topic(s) in 2 seconds"
              EM.add_timer(2) do
                a[:owner].each { |topic| delete_topic(topic) }
              end
            end

            shutdown if none_topics == 0 && owner_topics == 0
          end
        else
          shutdown
        end
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
      # @param [Hash] opts
      # @option opts [Boolean] :create_if_non_existent create the topic if non-existent, use this option with caution
      def subscribe(topic, opts = {}, &block)
        if opts[:create_if_non_existent]
          affiliations do |a|
            if a[:owner] && a[:owner].include?(topic)
              pubsub.subscribe(topic, nil, default_host, &callback_logging(__method__, topic, &block))
            else
              create_topic(topic) do
                pubsub.subscribe(topic, nil, default_host, &callback_logging(__method__, topic, &block))
              end
            end
          end
        else
          pubsub.subscribe(topic, nil, default_host, &callback_logging(__method__, topic, &block))
        end
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
          published_messages << OpenSSL::Digest::SHA1.new(message.to_s)
          block.call(stanza) if block
        end

        pubsub.publish(topic, message, default_host, &callback_logging(__method__, topic, &new_block))
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
        proc do |stanza|
          if stanza.respond_to?(:error?) && stanza.error?
            e_stanza = Blather::StanzaError.import(stanza)
            if [:unexpected_request].include? e_stanza.name
              logger.debug e_stanza
            elsif e_stanza.name == :conflict
              logger.debug e_stanza
            else
              logger.warn "#{e_stanza} Original: #{e_stanza.original}"
            end
          end
          logger.debug "#{m} SUCCEED" if stanza.respond_to?(:result?) && stanza.result?
          block.call(stanza) if block
        end
      end

      def default_host
        "#{HOST_PREFIX}.#{client.jid.domain}"
      end
    end
  end
end
end
