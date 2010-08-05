
require 'rubygems'
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

        lambda do |service, *args|
          service = service || ""
          xmpp_call(domain, service, *args)
        end
      end

      def XMPP.xmpp_call(domain, uri, *args)
        # Work out the service name and method from the URI
        service = uri.components[0]
        method = uri.components[1]
        # Build the message object
        message = Message.new(@@sender_id, new_message_id, service, method)
        args.each do |name, value|
          message.set_arg(name, value)
        end
        puts message.to_s
        p uri.components
        puts uri.to_s
        puts message.arg("a")
      end

      def XMPP.new_message_id
        @@message_id += 1
      end

      class Message < REXML::Element
        def initialize(name)
          super(name)
        end

        def method_missing(m, *args)
          # Special-case "message-id" to make a good Ruby identifier
          if m == :id
            m = "message-id"
          end
          el = elements[m.to_s]
          if el.nil?
            super(m, *args)
          else
            el.text
          end
        end
      end

      class RequestMessage < Message
        @args = nil
        def initialize(sender, id, service, method)
          super("service-request")
          add_element(REXML::Element.new("sender").add_text(sender))
          add_element(REXML::Element.new("message-id").add_text(id.to_s))
          add_element(REXML::Element.new("timestamp").add_text(Time.now.tv_sec.to_s))
          add_element(REXML::Element.new("service").add_text(service))
          add_element(REXML::Element.new("method").add_text(method))
          @args = add_element(REXML::Element.new("arguments"))
        end

        # Add an argument to the message, with given name and value.
        #
        # name:: [String]
        # value:: [String]
        def set_arg(name, value)
          arg = @args.add_element(REXML::Element.new("argument"))
          arg.add_element(REXML::Element.new("name").add_text(name))
          arg.add_element(REXML::Element.new("value").add_text(value))
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
        def initialize(sender, id)
          super(id)
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
        # the SERVICE_CALL_TIMEOUT then returns the response as an XML
        # doc (kind_of? Message).  Otherwise, raise a
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
          @domain.publish_to_node(message)

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
            @outstanding[message.id] = message
            @queues[message.id] = queue
          }
          queue
        end

        def remove(message)
          id = nil
          if message.kind_of? Integer
            id = message
          elsif message.kind_of? Message
            id = message.id
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
          id = response.id
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

    sp = OMF::ServiceCall::Dispatch.instance.new_service_proc(dom, OMF::ServiceCall::Dispatch::Uri.new("cmc"))
    sp.call("xyz", ["a", "b"])
    sp.call("allStatus", ["name", "omf.nicta.node1"], ["domain", "nicta"])
  end
end

run if __FILE__ == $PROGRAM_NAME
