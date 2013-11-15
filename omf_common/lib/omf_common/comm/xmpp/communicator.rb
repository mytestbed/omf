# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'blather'
require 'blather/client/dsl'

require 'omf_common/comm/xmpp/xmpp_mp'
require 'omf_common/comm/xmpp/topic'
require 'uri'
require 'socket'
require 'monitor'

module Blather
  class Stream
    def unbind
      cleanup
      raise NoConnection unless @inited
      @state = :stopped
      @client.receive_data @error if @error
      @client.unbind
    end
  end

  class Client
    def state
      @state
    end
  end
end

module OmfCommon
class Comm
  class XMPP
    class Communicator < OmfCommon::Comm
      include Blather::DSL

      attr_accessor :published_messages, :normal_shutdown_mode, :retry_counter

      HOST_PREFIX = 'pubsub'
      RETRY_INTERVAL = 180
      PING_INTERVAL = 1800

      PUBSUB_CONFIGURE = Blather::Stanza::X.new({
        :type => :submit,
        :fields => [
          { :var => "FORM_TYPE", :type => 'hidden', :value => "http://jabber.org/protocol/pubsub#node_config" },
          { :var => "pubsub#persist_items", :value => "0" },
          { :var => "pubsub#purge_offline", :value => "1" },
          { :var => "pubsub#send_last_published_item", :value => "never" },
          { :var => "pubsub#notify_retract",  :value => "0" },
          { :var => "pubsub#publish_model", :value => "open" }]
      })

      def conn_info
        { proto: :xmpp, user: jid.node, domain: jid.domain }
      end

      def string_to_address(a_string)
        "xmpp://#{a_string}@#{jid.domain}"
      end

      # Capture system :INT & :TERM signal
      def on_interrupted(&block)
        @cbks[:interpreted] << block
      end

      def on_connected(&block)
        @cbks[:connected] << block
      end

      # Set up XMPP options and start the Eventmachine, connect to XMPP server
      #
      def init(opts = {})
        @lock = Monitor.new

        @pubsub_host = opts[:pubsub_domain]
        if opts[:url]
          url = URI(opts[:url])
          username, password, server = url.user, url.password, url.host
        else
          username, password, server = opts[:username], opts[:password], opts[:server]
        end

        random_name = "#{Socket.gethostname}-#{Process.pid}"
        username ||= random_name
        password ||= random_name

        raise ArgumentError, "Username cannot be nil when connect to XMPP" if username.nil?
        raise ArgumentError, "Password cannot be nil when connect to XMPP" if password.nil?
        raise ArgumentError, "Server cannot be nil when connect to XMPP" if server.nil?

        @retry_counter = 0
        @normal_shutdown_mode = false

        username.downcase!
        jid = "#{username}@#{server}"
        client.setup(jid, password)
        connect(username, password, server)

        when_ready do
          if @not_initial_connection
            info "Reconnected"
          else
            info "Connected"
            OmfCommon::DSL::Xmpp::MPConnection.inject(Time.now.to_f, jid, 'connected') if OmfCommon::Measure.enabled?
            @cbks[:connected].each { |cbk| cbk.call(self) }
            # It will be reconnection after this
            @lock.synchronize do
              @not_initial_connection = true
            end
          end

          @lock.synchronize do
            @pong = true
            @ping_alive_timer = OmfCommon.el.every(PING_INTERVAL) do
              if @pong
                @lock.synchronize do
                  @pong = false # Reset @pong
                end
                ping_alive
              else
                warn "No PONG. No connection..."
                @lock.synchronize do
                  @ping_alive_timer.cancel
                end
                connect(username, password, server)
              end
            end
          end
        end

        disconnected do
          @lock.synchronize do
            @pong = false # Reset @pong
            @ping_alive_timer && @ping_alive_timer.cancel
          end

          if normal_shutdown_mode
            shutdown
          else
            warn "Disconnected... Last known state: #{client.state}"
            retry_interval = client.state == :initializing ? 0 : RETRY_INTERVAL
            OmfCommon.el.after(retry_interval) do
              connect(username, password, server)
            end
          end
        end

        trap(:INT) { @cbks[:interpreted].empty? ? disconnect : @cbks[:interpreted].each { |cbk| cbk.call(self) } }
        trap(:TERM) { @cbks[:interpreted].empty? ? disconnect : @cbks[:interpreted].each { |cbk| cbk.call(self) } }

        super
      end

      # Set up XMPP options and start the Eventmachine, connect to XMPP server
      #
      def connect(username, password, server)
        info "Connecting to '#{server}' ..."
        begin
          client.run
        rescue ::EventMachine::ConnectionError, Blather::Stream::ConnectionTimeout, Blather::Stream::NoConnection, Blather::Stream::ConnectionFailed => e
          warn "[#{e.class}] #{e}, try again..."
          OmfCommon.el.after(RETRY_INTERVAL) do
            connect(username, password, server)
          end
        end
      end

      # Shut down XMPP connection
      def disconnect(opts = {})
        # NOTE Do not clean up
        @lock.synchronize do
          @normal_shutdown_mode = true
        end
        info "Disconnecting..."
        shutdown
        OmfCommon::DSL::Xmpp::MPConnection.inject(Time.now.to_f, jid, 'disconnect') if OmfCommon::Measure.enabled?
      end

      # Create a new pubsub topic with additional configuration
      #
      # @param [String] topic Pubsub topic name
      def create_topic(topic, opts = {})
        OmfCommon::Comm::XMPP::Topic.create(topic)
      end

      # Delete a pubsub topic
      #
      # @param [String] topic Pubsub topic name
      def delete_topic(topic, pubsub_host = default_host, &block)
        pubsub.delete(topic, pubsub_host, &callback_logging(__method__, topic, &block))
      end

      # Subscribe to a pubsub topic
      #
      # @param [String] topic Pubsub topic name
      # @param [Hash] opts
      # @option opts [Boolean] :create_if_non_existent create the topic if non-existent, use this option with caution
      def subscribe(topic, opts = {}, &block)
        topic = topic.first if topic.is_a? Array
        OmfCommon::Comm::XMPP::Topic.create(topic, &block)
        OmfCommon::DSL::Xmpp::MPSubscription.inject(Time.now.to_f, jid, 'join', topic) if OmfCommon::Measure.enabled?
      end

      def _subscribe(topic, pubsub_host = default_host, &block)
        pubsub.subscribe(topic, nil, pubsub_host, &callback_logging(__method__, topic, &block))
      end

      def _create(topic, pubsub_host = default_host, &block)
        pubsub.create(topic, pubsub_host, PUBSUB_CONFIGURE, &callback_logging(__method__, topic, &block))
      end

      # Un-subscribe all existing subscriptions from all pubsub topics.
      def unsubscribe(pubsub_host = default_host)
        pubsub.subscriptions(pubsub_host) do |m|
          m[:subscribed] && m[:subscribed].each do |s|
            pubsub.unsubscribe(s[:node], nil, s[:subid], pubsub_host, &callback_logging(__method__, s[:node], s[:subid]))
            OmfCommon::DSL::Xmpp::MPSubscription.inject(Time.now.to_f, jid, 'leave', s[:node]) if OmfCommon::Measure.enabled?
          end
        end
      end

      def affiliations(pubsub_host = default_host, &block)
        pubsub.affiliations(pubsub_host, &callback_logging(__method__, &block))
      end

      # Publish to a pubsub topic
      #
      # @param [String] topic Pubsub topic name
      # @param [OmfCommon::Message] message Any XML fragment to be sent as payload
      def publish(topic, message, pubsub_host = default_host, &block)
        raise StandardError, "Invalid message" unless message.valid?

        message = message.marshall[1] unless message.kind_of? String
        if message.nil?
          debug "Cannot publish empty message, using authentication and not providing a proper cert?"
          return nil
        end

        new_block = proc do |stanza|
          published_messages << OpenSSL::Digest::SHA1.new(message.to_s)
          block.call(stanza) if block
        end

        pubsub.publish(topic, message, pubsub_host, &callback_logging(__method__, topic, &new_block))
        OmfCommon::DSL::Xmpp::MPPublished.inject(Time.now.to_f, jid, topic, message.to_s[/mid="(.{36})/, 1]) if OmfCommon::Measure.enabled?
      end

      # Event callback for pubsub topic event(item published)
      #
      def topic_event(additional_guard = nil, &block)
        guard_block = proc do |event|
          passed = !event.delayed? && event.items? && !event.items.first.payload.nil? #&&
            #!published_messages.include?(OpenSSL::Digest::SHA1.new(event.items.first.payload))

          if additional_guard
            passed && additional_guard.call(event)
          else
            passed
          end
        end

        mblock = proc do |stanza|
          OmfCommon::DSL::Xmpp::MPReceived.inject(Time.now.to_f, jid, stanza.node, stanza.to_s[/mid="(.{36})/, 1]) if OmfCommon::Measure.enabled? 
          block.call(stanza) if block
        end
        pubsub_event(guard_block, &callback_logging(__method__, &mblock))
      end

      private

      def initialize(opts = {})
        self.published_messages = []
        @cbks = {connected: [], interpreted: []}
        super
      end

      # Provide a new block wrap to automatically log errors
      def callback_logging(*args, &block)
        m = args.empty? ? "OPERATION" : args.join(" >> ")
        proc do |stanza|
          if stanza.respond_to?(:error?) && stanza.error?
            e_stanza = Blather::StanzaError.import(stanza)
            if [:unexpected_request].include? e_stanza.name
              logger.debug e_stanza
            elsif e_stanza.name == :conflict
              #logger.debug e_stanza
            else
              logger.warn "#{e_stanza} Original: #{e_stanza.original}"
            end
          end
          logger.debug "#{m} SUCCEED" if stanza.respond_to?(:result?) && stanza.result?
          block.call(stanza) if block
        end
      end

      def default_host
        @pubsub_host || "#{HOST_PREFIX}.#{jid.domain}"
      end

      def ping_alive
        client.write_with_handler Blather::Stanza::Iq::Ping.new(:get, jid.domain) do |response|
          info response
          @lock.synchronize do
            @pong = true
          end
        end
      end
    end
  end
end
end
