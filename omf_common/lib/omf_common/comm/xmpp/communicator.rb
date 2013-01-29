require 'omf_common/comm/xmpp/xmpp_mp'
require 'blather/client/dsl'

module OmfCommon
class Comm
  class XMPP
    class Communicator < OmfCommon::Comm
      include Blather::DSL

      attr_accessor :published_messages

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

      alias_method :on_connected, :when_ready

      # Set up XMPP options and start the Eventmachine, connect to XMPP server
      #
      def init(opts = {})
        username = opts[:username]
        password = opts[:password]
        server = opts[:server]
        #connect(username, password, server)
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
              OmfCommon.eventloop.after(2) do
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

        message = message.marshall unless message.kind_of? String

        new_block = proc do |stanza|
          published_messages << OpenSSL::Digest::SHA1.new(message.to_s)
          block.call(stanza) if block
        end

        pubsub.publish(topic, message, default_host, &callback_logging(__method__, topic, &new_block))
        MPPublished.inject(Time.now.to_f, jid, topic, message.to_s.gsub("\n",'')) if OmfCommon::Measure.enabled?
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

      %w(creation_ok creation_failed status released).each do |inform_type|
        define_method("on_#{inform_type}_message") do |*args, &message_block|
          msg_id = args[0].msg_id if args[0]
          event_block = proc do |event|
            message_block.call(OmfCommon::Message.parse(event.items.first.payload))
          end
          guard_block = proc do |event|
            (event.items?) && (!event.delayed?) &&
              event.items.first.payload &&
              (omf_message = OmfCommon::Message.parse(event.items.first.payload)) &&
              omf_message.operation == :inform &&
              omf_message.read_content(:inform_type) == inform_type.upcase &&
              (msg_id ? (omf_message.context_id == msg_id) : true)
          end
          topic_event(guard_block, &callback_logging(__method__, &event_block))
        end
      end

      private

      def initialize(opts = {})
        self.published_messages = []
        super
      end

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
