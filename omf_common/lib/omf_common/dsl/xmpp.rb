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
              if owner_topics > 0
                info "Deleting #{owner_topics} pubsub topic(s) in 2 seconds"
                EM.add_timer(2) do
                  a[:owner].each { |topic| delete_topic(topic) }
                end
              end
            else
              shutdown
            end
          end
        else
          shutdown
        end
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
          message =
            if block
              Message.send(m_name, *args, &block)
            elsif args[0].kind_of? Array
              Message.send(m_name) do |v|
                args[0].each do |opt|
                  if opt.kind_of? Hash
                    opt.each_pair do |key, value|
                      v.property(key, value)
                    end
                  else
                    v.property(opt)
                  end
                end
              end
            else
              Message.send(m_name)
            end

          OmfCommon::TopicMessage.new(message, self)
        end
      end

      # Event machine related method delegation
      %w(add_timer add_periodic_timer).each do |m_name|
        define_method(m_name) do |*args, &block|
          EM.send(m_name, *args, &block)
        end
      end

      %w(created status released failed).each do |inform_type|
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
      def topic_event(&block)
        guard_block = proc do |event|
          (event.items?) && (!event.delayed?) && event.items.first.payload
        end
        pubsub_event(guard_block, &callback_logging(__method__, &block))
      end

      # Return a topic object represents pubsub topic
      #
      def get_topic(topic_id)
        OmfCommon::Topic.new(topic_id, self)
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
            else
              logger.error e_stanza
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
