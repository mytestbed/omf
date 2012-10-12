require 'rubygems'
require 'xmpp4r'
require 'omf-common/mobject'
require 'omf-common/communicator/xmpp/omfXMPPServices'
require 'omf-common/omfVersion'
ROOT = "OMF_#{OMF::Common::MM_VERSION()}"

#Jabber::debug = true
module OMF
  module XMPP
    CONNECTION_TIMEOUT = 30
    READ_TIMEOUT = 15

    module PubSub
    end

    class XmppError < Exception; end
    class ConnectionTimeout < XmppError; end
    class ReadTimeout < XmppError; end
    class NoService < XmppError; end
    class ServerError < XmppError; end
    class ServerDisconnected < XmppError; end
    class Misconfigured < XmppError; end

    module Safely
      def with_timeout(timeout, exception, &block)
        Timeout::timeout(timeout, exception, &block)
      end

      def with_connect_timeout(&block)
        with_timeout(CONNECTION_TIMEOUT, ConnectionTimeout, &block)
      end

      def with_read_timeout(&block)
        with_timeout(READ_TIMEOUT, ReadTimeout, &block)
      end

      def nonblocking(type=:read, &block)
        case type
        when :read then with_read_timeout(&block)
        when :connect then with_connect_timeout(&block)
        else
          raise XmppError, "Unknown nonblocking type '#{type}'"
        end
      end

      #
      # Execute a block, catch its exceptions, and map them to
      # well-defined exceptions for this module, derived from
      # XmppException, then re-throw them.
      #
      def clean_exceptions(&block)
        begin
          block.call
        rescue Jabber::ServerError => e
          raise ServerError, e.message
        rescue ConnectionTimeout, Errno::ETIMEDOUT => e
          raise ConnectionTimeout, e.message
        rescue SystemCallError => e
          raise NoService, e.message
        rescue ReadTimeout => e
          raise e
        rescue Exception => e
          raise XmppError, e.message
        end
      end

      def handle(errors, &block)
        begin
          block.call
        rescue Jabber::ServerError => e
          errors.each_pair do |err, block|
            if e.error.type == :cancel and e.error.error == err
              return block.call
            end
          end
          raise e
        end
      end

      def ignore(errors, &block)
        begin
          block.call
        rescue Jabber::ServerError => e
          errors.each do |err|
            if e.error.type == :cancel and e.error.error == err
              return
            end
          end
          raise e
        end
      end
    end # module Safely

    class Connection < MObject
      include OMF::XMPP::Safely
      @connected = false
      @client = nil
      @mutex = nil
      @gateway = nil
      @user = nil
      @password = nil
      @port = nil
      @use_dnssrv = false
      @keep_alive_queue = nil
      @keep_alive_thread = nil
      @connect_cbs = nil
      @disconnect_cbs = nil

      attr_reader :client, :gateway, :user

      PING_INTERVAL = 10 # seconds
      PING_RETRY_LIMIT = 5

      def initialize(gateway, user, password, client = nil, port = nil, use_dnssrv = nil)
        if client.nil?
          raise Misconfigured, "Must specify XMPP gateway" if gateway.nil?
          raise Misconfigured, "Must specify XMPP user name" if user.nil?
          raise Misconfigured, "Must specify XMPP user password" if password.nil?
        end

        jid = "#{user}@#{gateway}"
        @gateway = gateway
        @password = password
        @user = jid
        @port = port || 5222
        @use_dnssrv = use_dnssrv || false

        @do_keep_alive = false

        if client.nil?
          @own_client = true
          @mutex = Mutex.new
          @connected = false
          @client = Jabber::Client.new(jid)
        else
          @own_client = false
          @client = client
          @connected = true # Assume we're already connected
        end
        @connect_cbs = Array.new
        @disconnect_cbs = Array.new
      end

      def connected?
        @connected
      end

      #
      # Connect to the XMPP server.  OMF requires a slightly more
      # managed connection than that offered by XMPP4r's
      # Jabber::Client class, so we take care of:
      #
      #  1. connecting to the pubsub gateway
      #  2. registering the user (if not already existing)
      #  3. authenticating the user (if already existing)
      #  4. sending the presence notification
      #
      def connect
        return if not @own_client # Don't allow connection attempts if we don't own the client stream
        @mutex.synchronize {
          return if @connected

          begin
            clean_exceptions {
              nonblocking(:connect) {  @client.connect(@use_dnssrv ? nil : @gateway, @port) }

              # Register, but if the user is already registered, authenticate instead
              nonblocking {
                handle("conflict" => lambda { @client.auth(@password) }) {
                  @client.register(@password)
                  @client.auth(@password)
                }
              }

              nonblocking { @client.send(Jabber::Presence.new) }
              @connected = true
            }
            @connect_cbs.each { |cb| cb.call }
          rescue Jabber::ServerDisconnected => e
            debug "XMPP server disconnected"
            @client.close
            @connected = false
            @do_keep_alive = false
            @keep_alive_thread.wakeup if not @keep_alive_thread.nil?
            @disconnect_cbs.each { |cb| cb.call }
          rescue Exception => e
            debug "Unknown exception in connect method: #{e}"
            @client.close
            @connected = false
            raise e
          end
        }
      end

      def close
        return if not @own_client # Don't allow closing the client stream if we don't own it.
        @disconnect_cbs.each { |cb| cb.call }

        @mutex.synchronize {
          clean_exceptions { nonblocking { @client.close } }
          @keep_alive_thread.wakeup if not @keep_alive_thread.nil?
          @connected  = false
          @do_keep_alive = false
        }
      end

      #
      # Send a ping to the PubSub server
      # implemented according to
      # http://xmpp.org/extensions/xep-0199.html#c2s
      #
      def ping
        iq = Jabber::Iq.new(:get, @client.jid.domain)
        iq.from = @client.jid
        ping = iq.add(REXML::Element.new('ping'))
        ping.add_namespace 'urn:xmpp:ping'
        @client.send_with_id(iq) do |reply|
          ret = reply.kind_of?(Jabber::Iq) and reply.type == :result
        end
      end

      def keep_alive?
        @do_keep_alive
      end

      def keep_alive
        @do_keep_alive = true

        @keep_alive_queue = Queue.new
        @keep_alive_thread = Thread.new {
          while keep_alive?
            sleep PING_INTERVAL
            @keep_alive_queue << :ping if keep_alive?
          end
        }

        Thread.new {
          error_count = 0
          cmd = :ping
          while cmd == :ping
            result = nil
            begin
              clean_exceptions { nonblocking { result = ping } }
            rescue XmppError => e
              warn "Trying to ping XMPP server: #{e}"
            end

            if not result
              error_count += 1
              warn "Error(#{error_count}) pinging XMPP server"
              if error_count > PING_RETRY_LIMIT
                warn "Reached XMPP server ping retry limit -- disconnected from server"
                Thread.exit
              end
            end

            # Wait for the next :ping from the PING_INTERVAL thread above
            if keep_alive?
              cmd = @keep_alive_queue.pop
            else
              cmd = :stop
            end
          end
        }.join
        @connected = false
        @do_keep_alive = false
        @disconnect_cbs.each { |cb| cb.call }
        return false
      end # keep_alive

      def on_connect(&block)
        @connect_cbs << block
      end

      def on_disconnect(&block)
        @disconnect_cbs << block
      end
    end # class Connection

    module PubSub
      class ServiceHelper < OmfServiceHelper
        def unsubscribe_from(node, subid=nil)
          unsubscribe_from_fixed(node, subid)
        end
      end # class ServiceHelper

      class Listener
        @node = nil
        @subscription
        @queue = nil

        attr_reader :node, :subscription, :queue

        # node:: [String]
        # subscription:: [Jabber::PubSub::Subscription]
        # queue:: [Queue]
        def initialize(node, subscription, queue = nil)
          @node = node
          @subscription = subscription
          @queue = queue || Queue.new
        end
      end # class Listener

      class Domain < MObject
        include OMF::XMPP::Safely
        @name = nil
        @service_helper = nil
        @subscriptions = nil
        @local_subscriptions = nil
        @listeners = nil
        @mutex = nil
        @event_count = 0

        @@domains = nil

        attr_reader :name

        def initialize(connection, domain)
          @event_count = 0
          @name = domain
          @subscriptions = Hash.new
          @local_subscriptions = Hash.new
          @listeners = Hash.new
          @mutex = Mutex.new
          clean_exceptions {
            @service_helper = PubSub::ServiceHelper.new(connection.client, "pubsub.#{domain}")
            @service_helper.add_event_callback { |event| process_event(event) }
          }
          @@domains = @@domains || Hash.new
          @@domains[domain] = self
        end

        def self.find(domain)
          @@domains[domain] unless @@domains.nil?
        end

        def event_node(event)
          items = event.first_element("items")
          return nil if items.nil?
          return items.attributes['node']
        end

        def event_payload(event)
          items = event.first_element("items")
          return nil if items.nil?
          item = items.first_element("item")
          return nil if item.nil?

          payload = item.elements[1]
          return payload
        end

        def process_event(event)
          @event_count += 1
          listeners = nil
          node = event_node(event)
          payload = event_payload(event)
          @mutex.synchronize {
            if @listeners.has_key? node
              listeners = @listeners[node].clone
            end
          }
          listeners.each { |s| s.queue << payload } if not listeners.nil? and not payload.nil?
        end

        def create_node(node, opts=nil)
          opts = opts || {
            "pubsub#title" => "#{name}",
            "pubsub#node_type" => "leaf",
            "pubsub#persist_items" => "1",
            "pubsub#max_items" => "1",
            "pubsub#notify_retract" => "0",
            "pubsub#publish_model" => "open"
          }

          config = config || Jabber::PubSub::NodeConfig.new(nil, opts)
          clean_exceptions { nonblocking { @service_helper.create_node(node, config) } }
        end

        def delete_node(node)
          clean_exceptions { nonblocking { @service_helper.delete_node(node) } }
        end

        #
        # Publish item to node.  If item is a Jabber::PubSub::Item,
        # then just pass it on to the service helper unchanged; if it
        # is some other kind of REXML::Element, then create a new
        # Jabber::PubSub::Item for it before passing it to the service
        # helper.
        #
        # node:: [String]
        # item:: [Jabber::PubSub::Item or REXML::Element]
        def publish_to_node(node, item)
          if not item.kind_of? Jabber::PubSub::Item
            new_item = Jabber::PubSub::Item.new
            new_item.add(item)
            item = new_item
          end
          clean_exceptions { nonblocking { @service_helper.publish_item_to(node,item) } }
        end

        def listen_to_node(node, queue = nil)
          listener = nil
          sub = nil
          resp = nil
          @mutex.synchronize {
            sub = @subscriptions[node]
          }
          if sub.nil?
            resp = clean_exceptions { nonblocking { @service_helper.subscribe_to(node) } }
          end
          raise "sub and resp simultaneously nil" if sub.nil? and resp.nil?
          raise "sub and resp simultaneously not nil" if not sub.nil? and not resp.nil?
          @mutex.synchronize {
            if not resp.nil?
              @subscriptions[node] = resp
              @local_subscriptions[node] = resp # we own this subscription
            end
            listener = Listener.new(node, @subscriptions[node], queue)
            listeners = @listeners[node] || []
            listeners << listener
            @listeners[node] = listeners
          }
          listener
        end

        def unlisten(listener)
          node = listener.node
          subid = listener.subscription.subid
          empty = false
          @mutex.synchronize {
            listeners = @listeners[node]
            listeners.delete(listener)
            empty = listeners.empty?
          }

          # Only unsubscribe if we own the subscription for this pubsub node
          if empty and not @local_subscriptions[node].nil?
            clean_exceptions { nonblocking { @service_helper.unsubscribe_from(node,sub) } }
            @mutex.synchronized {
              @listeners.delete(node)
              @subscriptions.delete(node)
              @local_subscriptions.delete(node)
            }
          end
        end

        # subscription:: [Jabber::PubSub::Subscription]
        def unsubscribe(subscription)
          node = subscription.node
          subid = subscription.subid
          clean_exceptions { nonblocking { @service_helper.unsubscribe_from(node, subid) } }
          @mutex.synchronize {
            if @subscriptions[node] == subscription
              @subscriptions.delete(node)
              @local_subscriptions.delete(node)
              @listeners.delete(node)
            end
          }
        end

        #
        # Get all pubsub subscriptions currently registered for our
        # user on the XMPP server and add them to the list of
        # monitored subscriptions.  Return the new subscriptions as a
        # list.  Subscriptions that already exist in the monitored
        # list of subscriptions will not be duplicated and will not be
        # returned
        #
        # If node is nil, request subscriptions to all nodes,
        # otherwise just to the specified node.
        #
        def request_subscriptions(node = nil, remove_duplicates = false)
          list = nil
          if node.nil?
            list = clean_exceptions { nonblocking { @service_helper.get_subscriptions_from_all_nodes } }
          else
            list = clean_exceptions { nonblocking { @service_helper.get_subscriptions_from(node) } }
          end
          duplicates = Array.new
          h = Hash.new
          list.each do |sub|
            if h.has_key? sub.node
              duplicates << sub
            else
              h[sub.node] = sub
            end
          end

          unique_list = h.values

          @mutex.synchronize {
            unique_list.each do |sub|
              if not @subscriptions.has_key?(sub.node)
                debug "Existing Subscription:  #{sub.subid}, #{sub.node}"
                @subscriptions[sub.node] = sub
              else
                duplicates << sub
              end
            end
          }

          if remove_duplicates
            duplicates.each do |sub|
              debug "Unsubscribing from duplicate subscription #{sub.node}, #{sub.subid}"
              clean_exceptions { nonblocking { @service_helper.unsubscribe_from(sub.node, sub.subid) } }
            end
          end
          list
        end
      end # class Domain
    end # module PubSub
  end # module XMPP
end # module OMF

def run(pubsub_domain)
  n1 = "abc"

  puts "CONNECTION..."
  connection = OMF::XMPP::Connection.new(pubsub_domain, n1, "123")
  puts "done"
  connection.connect

  # First, for this test, unsubscribe from all existing subscriptions
  domain = OMF::XMPP::PubSub::Domain.new(connection, pubsub_domain)
  subs = domain.request_subscriptions
#  subs.each { |s| domain.unsubscribe(s) }

  listener = domain.listen_to_node("/#{ROOT}")
  listener2 = domain.listen_to_node("/#{ROOT}/system")
  i = 1
  m = 0

  while true
    puts "sleep #{i}, messages: #{m}, queue: #{listener.queue.length}"
    sleep 1
    i += 1
    connection.ping

    item = Jabber::PubSub::Item.new
    hello = REXML::Element.new("hello")
    hello.add_text("Hello number #{i}!")
    item.add(hello)

    item2 = Jabber::PubSub::Item.new
    goodbye = REXML::Element.new("goodbye")
    goodbye.add_text("Goodbye #{m}")
    item2.add(goodbye)

    puts "Pub1"
    domain.publish_to_node("/#{ROOT}", item)
    puts "Pub2"
    domain.publish_to_node("/#{ROOT}/system", item2)

    puts "Servicing queue 1"
    until listener.queue.empty?
      p listener.queue.pop.to_s
    end

    puts "Cleared first queue"
    until listener2.queue.empty?
      p listener2.queue.pop.to_s
    end

    puts "Cleared second queue"

    m += 1
  end
end

def listener(domain)
  puts "CONNECTION..."
  connection = OMF::XMPP::Connection.new(domain, "abc", "123")
  puts "done"
  connection.connect

  domain = OMF::XMPP::PubSub::Domain.new(connection, domain)
  subs = domain.request_subscriptions

  listener = domain.listen_to_node("/#{ROOT}/system")

  while msg = listener.queue.pop
    puts "RECEIVED:  #{msg.to_s}"
  end
end


def dispatch
  case ARGV[0]
  when "listen" then listener(ARGV[1])
  when "txloop" then run(ARGV[1])
  end
end

dispatch if __FILE__ == $PROGRAM_NAME
