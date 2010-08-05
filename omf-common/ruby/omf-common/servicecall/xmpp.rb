
require 'time'
require 'xmpp4r'
require 'rexml/element'
require 'omf-common/xmpp'

#Jabber::debug = true

module OMF
  module ServiceCall

    SERVICE_CALL_TIMEOUT = 5  # seconds

    module XMPP
      @@connection = nil
      @@sender_id = nil
      @@message_id = 0

      # Borrow the connection from the "real" transport stack, if
      # it exists This means we don't have to worry about
      # splatting the main stack's pubsub subscriptions, etc., and
      # we don't have to have double the traffic to the XMPP
      # server.  It's a kludge...
      def XMPP.borrow_connection
        client = OMFPubSubTransport.instance.xmpp_services.client
        @@connection = OMF::XMPP::Connection.new("", "", "", client)
      end

      # connection:: [OMF::XMPP::Connection]
      def XMPP.set_connection(connection)
        @@connection = connection
      end

      def XMPP.connection
        @@connection
      end

      def XMPP.new_xmpp_domain(domainspec)
        pubsub_domain = domainspec[:uri]

        if @@connection.nil?
          # create the gateway connection
          gw = domainspec[:gateway] || pubsub_domain
          user = domainspec[:user]
          password = domainspec[:password]
          @@sender_id = domainspec[:sender_id]
          @@connection = OMF::XMPP::Connection.new(gw.to_s, user, password)
        end

        if not @@connection.connected?
          begin
            @@connection.connect
            if not @@connection.connected?
              raise ServiceCall::NoService, "Attemping to connect to XMPP server failed"
            end
          rescue OMF::XMPP::XmppError => e
            raise ServiceCall::NoService, e.message
          end
        end

        domain = OMF::XMPP::PubSub::Domain.new(@@connection, pubsub_domain)
        domain.request_subscriptions
        request_manager = RequestManager.new(domain)

        lambda do |service, *args|
          service = service || ""
          xmpp_call(request_manager, service, *args)
        end
      end

      def XMPP.xmpp_call(request_manager, uri, *args)
        # Work out the service name and method from the URI
        service = uri.components[0]
        method = uri.components[1]
        # Build the message object
        message = RequestMessage.new("sender" => @@sender_id,
                                     "message-id" => new_message_id.to_s,
                                     "service" => service,
                                     "method" => method)
        args.each do |name, value|
          message.set_arg(name, value)
        end
        puts message.to_s
        p uri.components
        puts uri.to_s
        puts message.arg("a")
        request_manager.make_request(message, "/OMF/system")
      end

      def XMPP.new_message_id
        @@message_id += 1
      end

      class Message < REXML::Element
        # These three Hashes are populated by subclasses
        @@name = Hash.new # Tag name for the root tag of this type of message
        @@required_keys = Hash.new  # Tag names of required key/value pairs in message header
        @@required_payload = Hash.new # Require payload tags (arbitrary XML child nodes)

        def initialize(name)
          super(name)
        end

        def method_missing(m, *args)
          # Automatically translate underscores to hyphens
          # Hyphens look better in XML...
          m = m.to_s.sub("_", "-")
          el = elements[m]
          if el.nil?
            super(m, *args)
          else
            el.text
          end
        end

        def add_key(name, value)
          add_element(REXML::Element.new(name).add_text(value))
        end

        def add_key_to_element(element, name, value)
          element.add_element(REXML::Element.new(name).add_text(value))
        end

        def self.name
          @@name[self]
        end

        def self.required_keys
          @@required_keys[self]
        end

        def self.required_payload
          @@required_payload[self]
        end

        def self.try_text(element, name)
          if not element.elements[name].nil?
            element.elements[name].text
          else
            nil
          end
        end

        # element:: [REXML::Element]
        def self.from_element(element)
          return nil if element.name != self.name
          props = Hash.new

          required_keys.each do |key|
            props[key] = self.try_text(element, key) || nil
          end

          have_nil = false
          props.each_value { |v| have_nil = true if v.nil? }

          return nil if have_nil
          result = self.new(props)

          required_payload.each do |tag|
            el = element.elements[tag]
            if not el.nil?
              result.add_element(el)
            end
          end
          result
        end
     end

      class RequestMessage < Message
        @@name[self] = "service-request"
        @@required_keys[self] = [ "sender",
                                  "message-id",
                                  "timestamp",
                                  "service",
                                  "method" ]
        @@required_payload[self] = [ "arguments" ]

        @args = nil

        def initialize(props)
          super("service-request")
          if not props.has_key? "timestamp"
            props["timestamp"] = Time.now.tv_sec.to_s
          end

          @@required_keys[self.class].each { |name| add_key(name, props[name]) }

          @args = add_element(REXML::Element.new("arguments"))
        end

        # Add an argument to the message, with given name and value.
        #
        # name:: [String]
        # value:: [String]
        def set_arg(name, value)
          arg = @args.add_element(REXML::Element.new("argument"))
          add_key_to_element(arg, "name", name)
          add_key_to_element(arg, "value", value)
        end

        # Return the value of a named argument
        #
        # name:: [String]
        def arg(name)
          args = elements["arguments"]
          args.each do |arg|
            arg_name = arg.elements["name"].text
            if arg_name == name
              return arg.elements["value"].text
            end
          end
          nil
        end

        # Return this Message's arguments as a hash.
        def arguments
          result = Hash.new
          args = elements["arguments"]
          args.collect do |arg|
            name = arg.elements["name"].text
            value = arg.elements["value"].text
            result[name] = value
          end
          result
        end
      end # class RequestMessage

      class ResponseMessage < Message
        @@name[self] = "service-response"
        @@required_keys[self] = [ "response-to",
                                  "message-id",
                                  "timestamp",
                                  "status" ]
        @@required_payload[self] = [ "result" ]

        def initialize(props)
          super("service-response")
          if not props.has_key? "timestamp"
            props["timestamp"] = Time.now.tv_sec.to_s
          end

          @@required_keys[self.class].each { |name| add_key(name, props[name]) }
        end
      end

      class RequestManager

        #
        # Create a new RequestManager for the given XMPP pubsub
        # domain.
        #
        # domain:: [OMF::XMPP::PubSub::Domain]
        def initialize(domain)
          @domain = domain
          @mutex = Mutex.new
          @matchers = Hash.new
        end

        #
        # Send a service request and wait for a reply from the remote
        # AM.  If the remote AM replies with a service response within
        # the SERVICE_CALL_TIMEOUT then return the response as an XML
        # doc (actually, kind_of? Message).  Otherwise, raise a
        # ServiceCall::Timeout exception.
        #
        # Node is the pubsub node to publish the service request to.
        #
        # message:: [kind_of? Message]
        # node:: [String]
        def make_request(message, node)
          if not @matchers.has_key? node
            new_matcher(node)
          end

          matcher = nil
          @mutex.synchronize {
            matcher = @matchers[node]
          }
          queue = matcher.add(message)

          # FIXME:  Handle exceptions
          @domain.publish_to_node(node, message)

          # Timeout thread
          Thread.new {
            sleep(SERVICE_CALL_TIMEOUT)
            matcher = nil
            @mutex.synchronize {
              matcher = @matchers[node]
            }
            matcher.remove(message)
            queue << :timeout
          }

          response = queue.pop
          if response == :timeout and queue.empty?
            raise ServiceCall::Timeout, "Timeout waiting for ServiceCall:  #{message.to_s}"
          elsif not queue.empty?
            response = queue.pop
          end

          return response
        end

        #
        # Create a new ResponseMatcher for a given XMPP pubsub node on
        # our pubsub domain.  The ResponseMatcher is cached internally
        # and used for any subsequent requests to the given node.
        #
        # node:: [String]
        def new_matcher(node)
          # FIXME:  Catch exceptions
          matcher = ResponseMatcher.new(node, @domain)
          @mutex.synchronize {
            @matchers[node] = matcher
          }
        end
      end # class RequestManager

      class ResponseMatcher

        #
        # Create a new response matcher listening on the given node in
        # the given pubsub domain.
        #
        # node:: [String]
        # domain:: [OMF::XMPP::PubSub::Domain]
        def initialize(node, domain)
          @mutex = Mutex.new
          @domain = domain
          @node = node
          @listener = @domain.listen_to_node(node)
          @outstanding = Hash.new
          @queues = Hash.new
          @thread = Thread.new { serve_responses }
        end

        def add(message)
          queue = Queue.new
          @mutex.synchronize {
            @outstanding[message.message_id] = message
            @queues[message.message_id] = queue
          }
          queue
        end

        def remove(message)
          id = nil
          if message.kind_of? Integer
            id = message
          elsif message.kind_of? Message
            id = message.message_id
          else
            raise "Trying to remove unknown type of message '#{message.class()} from message matcher"
          end

          @mutex.synchronize {
            @outstanding[id] = nil
            @queues[id] = nil
          }
        end

        def serve_responses
          while response = @listener.queue.pop
            request_id, queue = match_request(response)
            if not request_id.nil?
              queue << response
              remove(request_id)
            end
          end
        end

        def match_request(response)
          return [nil, nil] if response.name != "service-response"
          id = response.message_id
          request = nil
          queue = nil
          @mutex.synchronize {
            request = @outstanding[id]
            queue = @queues[id]
          }
          if not request.nil? and not queue.nil? and response.sender == request.sender
            [id, queue]
          else
            [nil, nil]
          end
        end
      end # class ResponseMatcher
    end # module XMPP
  end # module ServiceCall
end # module OMF

def run

  require 'omf-common/servicecall'
  if false
    domain = OMF::ServiceCall::XMPP.new_xmpp_domain(:uri => "203.143.170.124",
                                                    :user => "abc",
                                                    :password => "123")
    domain.call("cmc/allStatus", ["name", "omf.nicta.node1"])
  else
    dom = OMF::ServiceCall.add_domain(:type => :xmpp,
                                      :uri => "203.143.170.124",
                                      :user => "abc",
                                      :password => "123")

    puts "Sleeping..."
    sleep 3
    puts "done"

#    xdom = OMF::XMPP::PubSub::Domain.new(OMF::ServiceCall::XMPP.connection,"203.143.170.124")
#    msg = REXML::Element.new("test-message").add_text("servicecall/xmpp.rb")
#    xdom.publish_to_node("/OMF/system", item)

    if true
      sp = OMF::ServiceCall::Dispatch.instance.new_service_proc(dom, OMF::ServiceCall::Dispatch::Uri.new("cmc"))
      begin
        sp.call("xyz", ["a", "b"])
      rescue OMF::ServiceCall::Timeout => e
        puts "Service call to 'cmc.xyz' timed out"
      end

      begin
        sp.call("allStatus", ["name", "omf.nicta.node1"], ["domain", "nicta"])
      rescue OMF::ServiceCall::Timeout => e
        puts "Service call to 'cmc.allStatus' timed out"
      end
    end
  end
end

def add_key(el, name, value)
  el.add_element(REXML::Element.new(name).add_text(value))
end

def run2
  doc = REXML::Document.new
  resp = REXML::Element.new("service-response")
  add_key(resp, "response-to", "x@y.z")
  add_key(resp, "message-id", "42")
  add_key(resp, "timestamp", "122345678")
  add_key(resp, "status", "OK")
  resp.add_element(REXML::Element.new("result").add_text("MY RESULT TEXT"))

  puts "REL="
  puts resp.to_s

  y = OMF::ServiceCall::XMPP::ResponseMessage.from_element(resp)
  puts y.to_s
  p y.class()

  req = REXML::Element.new("service-request")
  add_key(req, "sender", "x@y.z")
  add_key(req, "message-id", "42")
  add_key(req, "timestamp", "122345678")
  add_key(req, "service", "cmc")
  add_key(req, "method", "allStatus")
  args = req.add_element(REXML::Element.new("arguments"))
  arg = args.add_element("argument")
  arg.add_element("name").add_text("name")
  arg.add_element("value").add_text("omf.nicta.node1")
  arg = args.add_element("argument")
  arg.add_element("name").add_text("domain")
  arg.add_element("value").add_text("norbit")

  puts "REQ="
  puts req.to_s
  y = OMF::ServiceCall::XMPP::RequestMessage.from_element(req)

  puts y.to_s

end

run if __FILE__ == $PROGRAM_NAME