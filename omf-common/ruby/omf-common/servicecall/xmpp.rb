#
# Copyright 2010-2011 National ICT Australia (NICTA), Australia
#
# Copyright 2010-2011 WINLAB, Rutgers University, USA
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#

require 'rubygems'
require 'time'
require 'xmpp4r'
require 'rexml/element'
require 'omf-common/xmpp'
require 'omf-common/servicecall/endpoint'
require 'omf-common/omfPubSubTransport'

module OMF
  module Services
    class XmppEndpoint < Endpoint
      register :xmpp

      @@connection = nil
      @@selector = nil
      @@sender_id = nil

      def self.connection=(connection)
        @@connection = connection
      end

      # Borrow the connection from the "real" transport stack, if
      # it exists This means we don't have to worry about
      # splatting the main stack's pubsub subscriptions, etc., and
      # we don't have to have double the traffic to the XMPP
      # server.  It's a kludge...
      def self.borrow_connection
        client = OMFPubSubTransport.instance.xmpp_services.clientHelper
        @@connection = OMF::XMPP::Connection.new("", "", "", client)
      end

      def self.sender_id=(id)
        @@sender_id = id
        @@sender_id
      end

      def self.pubsub_selector(&block)
        @@selector = block
      end

      def initialize(type, uri, *args)
        super(type, uri)
        @message_id = 0
        @pubsub_domain = nil
        @request_manager = nil
        opts = args[2] if args[2].kind_of? Hash
        node = @@selector.call(opts) if not @@selector.nil?
      end

      def new_message_id
        @message_id += 1
      end

      #
      # Make sure the pubsub domain is set up, if possible.  If not possible,
      # @pubsub_domain will be nil, e.g. no connection yet.
      #
      def ensure_request_manager
        if (not @@connection.nil?) and @@connection.connected?
          @pubsub_domain = OMF::XMPP::PubSub::Domain.find(domain)
          if @pubsub_domain.nil?
            @pubsub_domain = OMF::XMPP::PubSub::Domain.new(@@connection,
                                                           domain)
            @pubsub_domain.request_subscriptions unless @pubsub_domain.nil?
          end
          if @request_manager.nil?
            @request_manager = OMF::ServiceCall::XMPP::RequestManager.new(@pubsub_domain)
          end
        else
          debug "Not initializing ReqMan b/c #{@@connection}"
          debug "--> is/is not connected? #{@@connection.connected?}" unless @@connected.nil?
        end
      end

      def match?(type, uri, *args)
        service = args[0]
        method = args[1]
        has_method?(service, method)
      end

      def send_request(service=nil, method=nil, *args, &block)
        ensure_request_manager
        if @request_manager.nil?
          raise "Unable to make service call -- not connected to XMPP server?"
        end
        debug "ServiceCall #{service}.#{method}"
        # Build the message object
        message = OMF::ServiceCall::XMPP::RequestMessage.new("sender" => @@sender_id,
                                                             "message-id" => new_message_id.to_s,
                                                             "service" => service,
                                                             "method" => method)

        opts = args.find { |a| a.kind_of? Hash }

        pubsub_node = @@selector.call(opts) || "/OMF/system"

        if args.length == 1 and args[0].kind_of? Hash
          args[0].each_pair do |name, value|
            message.set_arg(name.to_s, value)
          end
        else
          args.each do |name, value|
            message.set_arg(name, value)
          end
        end


        wait_policy = :wait
        if service.nil?
          wait_policy = :multiple
        elsif not opts.nil? and opts[:nonblocking]
          wait_policy = :nowait
        end
        r = @request_manager.make_request(message, pubsub_node, wait_policy, &block)

        if r.kind_of? REXML::Element then
          doc = REXML::Document.new
          doc.add(r)
          doc
        else
          r
        end
      end

    end # class XmppEndpoint
  end # module Services

  module ServiceCall

    SERVICE_CALL_TIMEOUT = 10  # seconds

    module XMPP
      class Message < REXML::Element
        # These three Hashes are populated by subclasses
        @@name = Hash.new # Tag name for the root tag of this type of message
        @@required_keys = Hash.new  # Tag names of required key/value pairs in message header
        @@optional_keys = Hash.new  # Tag names of optional key/value pairs in message header
        @@required_payload = Hash.new # Require payload tags (arbitrary XML child nodes)

        def initialize(name)
          super(name)
        end

        def method_missing(m, *args)
          # Automatically translate underscores to hyphens
          # Hyphens look better in XML...
          mstr = m.to_s.sub("_", "-")
          # We can't use the 'method' tag name directly because the
          # Ruby Object class defines a method named 'method' that
          # does method lookup on the object itself.  So we special
          # case it by mapping the method 'method_name' to the XML tag
          # 'method'.
          if mstr == "method-name"
            mstr = "method"
          end
          el = elements[mstr]
          if el.nil?
            if self.class.required_keys.include? mstr or self.class.optional_keys.include? mstr
              nil
            else
              super(m, *args)
            end
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

        def self.optional_keys
          @@optional_keys[self]
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

          optional_keys.each do |key|
            props[key] = self.try_text(element, key) || nil
          end

          result = self.new(props)

          required_payload.each do |tag|
            el = element.elements[tag]
            if not el.nil?
              result.add_element(el)
            end
          end
          result
        end
     end # class Message

      class RequestMessage < Message
        @@name[self] = "service-request"
        @@required_keys[self] = [ "sender",
                                  "message-id",
                                  "timestamp" ]
        @@optional_keys[self] = [ "service",
                                  "method" ]
        @@required_payload[self] = [ "arguments" ]

        @args = nil

        def initialize(props)
          super("service-request")
          if not props.has_key? "timestamp"
            props["timestamp"] = Time.now.tv_sec.to_s
          end

          @@required_keys[self.class].each { |name| add_key(name, props[name]) }
          @@optional_keys[self.class].each { |name| add_key(name, props[name]) }

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
          args = elements.each("arguments/argument") do |arg|
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
        @@optional_keys[self] = []
        @@required_payload[self] = [ "result" ]

        def initialize(props)
          super("service-response")
          if not props.has_key? "timestamp"
            props["timestamp"] = Time.now.tv_sec.to_s
          end

          @@required_keys[self.class].each { |name| add_key(name, props[name]) }
        end

        #
        # Set the <result/> tag of this response message, giving it
        # the xml element as its sole child.
        #
        # xml:: [REXML::Element or String]
        def set_result(xml)
          el = elements["result"]
          el = add_element("result") if el.nil?
          if xml.kind_of? REXML::Element
            el << xml
          else
            el.add_text(xml)
          end
        end

        #
        # Return the <result/> element from the response message as a
        # REXML::Element.
        #
        def result
          if not elements["result"].nil?
            r = elements["result"].elements[1]
            if r.nil?
              elements["result"].text
            else
              r
            end
          else
            nil
          end
        end
      end # class ResponseMessage

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
        def make_request(message, node, wait_policy = :wait, &block)
          matcher = nil
          @mutex.synchronize {
            if not @matchers.has_key? node
              new_matcher(node)
            end
            matcher = @matchers[node]
          }
          if wait_policy != :nowait
            queue = matcher.add(message)
          end

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

          if wait_policy == :wait
            response = queue.pop
            if response == :timeout and queue.empty?
              raise ServiceCall::Timeout, "Timeout waiting for ServiceCall:  #{message.to_s}"
            elsif not queue.empty?
              response = queue.pop
            end
          elsif wait_policy == :multiple
            responses = []
            while (r = queue.pop) != :timeout
              responses << r
              if block_given?
                block.call(r)
              end
            end
            if responses.empty?
              raise ServiceCall::Timeout, "Timeout waiting for ServiceCall:  #{message.to_s}"
            end
            response = responses
          end
          if wait_policy == :nowait
            nil
          else
            response
          end
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
          @matchers[node] = matcher
        end
      end # class RequestManager

      class ResponseMatcher < MObject

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
            @outstanding[message.message_id.to_i] = message
            @queues[message.message_id.to_i] = queue
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
            raise "Trying to remove unknown type of message '#{message.class()}' (#{message.to_s}) from message matcher"
          end

          @mutex.synchronize {
            @outstanding.delete(id.to_i)
            @queues.delete(id.to_i)
          }
        end

        # For debugging
        def dump_response(response)
          if not response.nil? and response.kind_of? ResponseMessage
            debug "----"
            debug "Received service-response ="
            debug " --> response-to: #{response.response_to}"
            debug " --> message-id:  #{response.message_id}"
            debug " --> timestamp:   #{response.timestamp}"
            debug " --> status:      #{response.status}"
            debug "----"
          end
        end

        def serve_responses
          begin
            while response = @listener.queue.pop
              response = ResponseMessage.from_element(response)
              next if response.nil?
              request_id, queue = match_request(response)
              rid = request_id.to_i

              if not request_id.nil?
                status = response.status
                result = response.result
                if status != "OK"
                  warn "Service call response error: #{status}"
                  remove(request_id)
                  raise status
                elsif result.nil?
                  warn "Service call returned OK but no result body was found in:"
                  warn response.to_s
                  warn response.result.to_s
                  queue << ""
                else
                  queue << response.result
                end
              end
            end
          rescue Exception => e
            debug "Got an exception waiting for a response to a service call; retrying.  Error was: #{e.message}; retrying"
            e.backtrace.each { |b| debug b }
            debug response
            retry
          end
        end

        def match_request(response)
          return [nil, nil] if response.name != "service-response"
          id = response.message_id.to_i
          request = nil
          queue = nil
          @mutex.synchronize {
            request = @outstanding[id]
            queue = @queues[id]
          }

          if not request.nil? and not queue.nil? and response.response_to == request.sender
            [id, queue]
          else
            [nil, nil]
          end
        end
      end # class ResponseMatcher
    end # module XMPP
  end # module ServiceCall
end # module OMF
