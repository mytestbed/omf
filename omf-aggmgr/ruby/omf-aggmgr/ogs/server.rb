#
# Copyright (c) 2010 National ICT Australia (NICTA), Australia
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

require 'rexml/document'
require 'rexml/element'
require 'stringio'
require 'base64'
require 'webrick'
require 'omf-common/mobject'
require 'omf-common/communicator/omfProtocol'
require 'omf-common/communicator/xmpp/xmpp'
require 'omf-common/servicecall'
require 'omf-common/omfVersion'

class AggmgrServer < MObject

  @stopped = nil

  # List of default slices that we should always serve
  @default_slices = []

  # Hash of Hashes.  @services[myservice][mymethod] is a block to
  # execute when a request for 'myservice.mymethod' is received.
  @mounted_services = nil

  # The underlying, implementation-specific server.
  attr_accessor :server

  def initialize(params)
    super(self.class)
    @stopped = true
    @mounted_services = Hash.new
    @default_slices = params[:default_slices]
    info "Serving the default slices: '#{@default_slices.inspect}'"
  end

  #
  #  Create a new server of given type.  The params argument should
  #  contain a section named after the type of server, containing any
  #  configuration items that are required by this type of server.
  #
  #  - type = the type of server to create.  Either :xmpp or :http
  #  - params = [Hash] the configuration parameters passed to omf-aggmgr
  #
  def self.create_server(type, params)
    debug :gridservices, "Starting server type #{type}"
    case type
    when :http
      HttpAggmgrServer.new(params)
    when :xmpp
      XmppAggmgrServer.new(params)
    else
      raise "Unknown AggmgrServer type '#{type}'"
    end
  end

  #
  #  Start the server.  Once the start method is called, the server
  #  will be up and accepting client requests.
  #
  def start
    raise unimplemented_method_exception("start")
  end

  #
  #  Stop the server.
  #
  def stop
    raise unimplemented_method_exception("stop")
  end

  def stopped?
    @stopped
  end

  #
  #  Mount a new service on this server.
  #
  #  - service_class = [Class] the Ruby class that implements the service
  #
  def mount(service_class)
    raise unimplemented_method_exception("mount")
  end

  def unimplemented_method_exception(method_name)
    "AggmgrServer subclass '#{self.class}' must implement #{method_name}()"
  end

  #
  # Build an XML document describing the services offered by this
  # AM server.
  #
  # Returns: REXML::Document
  #
  def all_services_summary
    debug "Building service summary"
    doc = REXML::Document.new
    root = doc.add(REXML::Element.new("serviceGroups"))
    @mounted_services.each do |path, service_class|
      description = service_class.description
      name = service_class.serviceName
      group = REXML::Element.new("serviceGroup")
      group.add_attributes({"path" => path,
                             "name" => name})
      group.add_element(REXML::Element.new("info").add_text(description))
      root.add_element(group)
    end
    doc
  end

  #
  # Build an XML document describing the methods offered by a
  # particular service.
  #
  # service_class:: [kind_of? AbstractService]
  #
  # Returns: REXML::Document
  #
  def service_description(service_class)
    service_name = service_class.serviceName

    doc = REXML::Document.new
    root = doc.add(REXML::Element.new("services"))
    el = service_class.to_xml(root)
    el.attributes['prefix'] = "/#{service_name}"

    doc
  end
end

class HttpAggmgrServer < AggmgrServer
  @port = nil
  @config_dir = nil

  def initialize(params)
    debug(:gridservices, "Initializing HTTP server manager")
    super(params)
    http_params = params[:http]
    @port = http_params[:port] || DEF_WEB_PORT
    @bindaddress = http_params[:address] || DEF_WEB_ADDRESS
    @config_dir = params[:configDir]
    @server = HTTPServer.new(:Port => @port,
                             :BindAddress => @bindaddress,
                             :Logger => Log4r::Logger.new("#{MObject.logger.fullname}::web"))

    path = File.dirname(@config_dir) + "/favicon.ico"
    @server.mount("/favicon.ico", HTTPServlet::FileHandler, path) {
      raise HTTPStatus::NotFound, "#{path} not found."
    }
    @server.mount_proc('/') do |req, res|
      res['Content-Type'] = "text/xml"
      ss = StringIO.new
      ss.write("<?xml version='1.0'?>\n")
      formatter = REXML::Formatters::Default.new
      doc = all_services_summary
      formatter.write(doc, ss)
      res.body = ss.string
    end
  end

  def HttpAggmgrServer.response_ok(res)
    res['Content-Type'] = "text/plain"
    res.body = "OK"
  end

  def self.response_xml(res, xml)
    res['Content-Type'] = 'text/xml'
    s = StringIO.new
    formatter = REXML::Formatters::Default.new
    formatter.write(xml, s)
    res.body = s.string
  end

  def self.response_plain_text(res, text)
    res['Content-Type'] = 'text/plain'
    res.body = text
  end

  def start
    @stopped = false
    @server.start
  end

  def stop
    info "Shutting down HTTP server"
    @server.shutdown
    @stopped = true
  end

  def mount(service_class)
    debug " Mounting #{service_class}"
    service_name = service_class.serviceName
    service_calls = service_class.serviceCalls
    service_calls.each do |name, params|
      mount_point = "/#{service_name}/#{name}"
      debug "Mounting #{mount_point}"
      @server.mount_proc(mount_point) do |req, res|
        debug "Service call:  #{service_name}.#{name}"
        proc = params[:proc]
        if proc.nil? then
          raise HTTPStatus::NotImplemented, "No support for service '#{service_name}', subservice '#{name}'"
        end

        p_list = params[:param_list] || []
        args = p_list.collect { |p| req.query[p.to_s] }
        result = proc.call(*args)

        if result == true then
          HttpAggmgrServer.response_ok(res)
        elsif result.kind_of? REXML::Element then
          HttpAggmgrServer.response_xml(res, result)
        else
          HttpAggmgrServer.response_plain_text(res, result.to_s)
        end
      end
    end

    @server.mount_proc("/#{service_name}") do |req, res|
      res['ContentType'] = "text/xml"

      ss = StringIO.new
      ss.write("<?xml version='1.0'?>\n")
      formatter = REXML::Formatters::Default.new
      doc = service_description(service_class)
      formatter.write(doc, ss)
      res.body = ss.string
    end

    @mounted_services[service_name] = service_class
  end

  def register_legacy_service_class(service_class)
    @mounted_services[service_class.serviceName] = service_class
  end
end

class XmppAggmgrServer < AggmgrServer

  include OmfProtocol
  include OMF::ServiceCall::XMPP
  SLICE_PREFIX = "/OMF_#{OMF::Common::MM_VERSION()}"
  SLICE_LEGACY_PREFIX = "/OMF"
  SLICE_SUFFIX = "resources"

  attr_reader :domains, :connection

  # Hash of Hashes.  @services[myservice][mymethod] is a block to
  # execute when a request for 'myservice.mymethod' is received.
  @services = nil

  def initialize(params)
    debug "Initializing XMPP PubSub AM server"
    super(params)
    xmpp_params = params[:xmpp]
    @server = xmpp_params[:server]
    @user = xmpp_params[:user]
    @password = xmpp_params[:password]
    @port = xmpp_params[:port]
    @use_dnssrv = xmpp_params[:use_dnssrv]
    @omf53 = xmpp_params[:accept_omf53_requests]
    @connection = xmpp_params[:connection]

    @services = Hash.new
    @listeners = Hash.new
    @dispatcher_threads = Array.new
    @domains = Hash.new
  end

  # Start listening for service requests on node in domain.
  #
  # domain:: [OMF::XMPP::PubSub::Domain]
  # node:: [String]
  def make_dispatcher(domain, node)
    debug "Creating dispatcher on '#{domain.name}' for '#{node}'"
    listener = domain.listen_to_node(node)

    @listeners[domain] = @listeners[domain] || []
    @listeners[domain] << listener

    @dispatcher_threads << Thread.new {
      begin
        while msg = listener.queue.pop
          if msg == :stop
            break
          end
          # Execute requests in their own thread, so that we can be re-entrant
          Thread.new {
            request = OMF::ServiceCall::XMPP::RequestMessage.from_element(msg)
            # Ignore anything that isn't well-formed
            if not request.nil?

# JW 2010-10-05 Disable the timestamp checking code because we can't rely on the EC
# machine's clock being properly synchronized.

#              timestamp = request.timestamp.to_i
#              now = Time.now.tv_sec
#              if now - timestamp > 30
#                # Ignore stale messages
#                debug "Ignoring stale message #{request.message_id}"
#              elsif now < timestamp
#                # Ignore messages from the future
#                debug "Ignoring future message #{request.message_id}"
#              else

              send_response = true

              if true # Accept all messages regardless of timestamp
                sender = request.sender
                message_id = request.message_id
                service = request.service
                method = request.method_name

                result = nil
                error_result = nil
                status = nil
                if service.nil? or method.nil?
                  if not service.nil?
                    service_class = @mounted_services[service]

                    if method.nil? and not service_class.nil?
                      result = service_description(service_class)
                      status = "OK"
                    elsif method.nil? and service_class.nil?
                      send_response = false # we don't serve this service, don't respond
                    end
                  else
                    result = all_services_summary
                    status = "OK"
                  end
                else
                  arguments = request.arguments
                  service_hash = @services[service]

                  # Ignore requests for unknown services -- another AM might be serving them.
                  if not service_hash.nil?
                    proc = service_hash[method]
                    if proc.nil?
                      # return an error response
                      error_result = "#{service}.#{method}: Method not supported"
                    else
                      begin
                        result = proc.call(arguments)
                      rescue Exception => e
                        error_result = e.message
                      end

                      if error_result.nil?
                        status = "OK"
                      else
                        status = error_result
                      end
                    end
                  else
                    send_response = false # we don't serve this service, don't respond
                  end
                end

                if result == true
                  result = nil
                end

                if send_response
                  response = ResponseMessage.new("response-to" => sender,
                                                 "message-id" => message_id,
                                                 "status" => status)
                  if not result.nil?
                    response.set_result(result)
                  end

                  begin
                    domain.publish_to_node(node, response)
                  rescue Exception => e
                    error "Error sending service-response (for request from #{sender} on node #{node}): #{e.message}"
                  end
                end # send_response
              end # message not stale
            else
              # Ignore messages that are not <service-request/>'s
            end # if not request.nil?
          } # Request execution thread

        end # while msg = listener.queue.pop
      rescue Exception => e
        warn "Received an exception in dispatcher loop for node #{node}: #{e.message}\n#{e.backtrace}"
        retry
      end
      info "Shutting down XMPP dispatcher on '#{domain.name}' node '#{node}'"
      domain.unlisten(listener)
    }
  end

  def setup_dispatchers
    # We need to talk to at least one pubsub domain -- use the local
    # gateway as the default domain.  In future, we'll need to talk to
    # multiple domains, but the architecture isn't settled yet, so we
    # leave it at just the local domain for the moment.
    @domains[@server] = OMF::XMPP::PubSub::Domain.new(@connection, @server)
    @domains.each_value do |domain|
      # Get existing subscriptions from the server, unsubscribing
      # from duplicates (to cleanup from crashes, etc.).
      domain.request_subscriptions(nil, true)
      # Add the system node and the nodes for each default slice
      nlist = @default_slices
      nlist.each do |node|
        begin
          make_dispatcher(domain, "#{SLICE_PREFIX}/#{node}/#{SLICE_SUFFIX}")
        rescue Exception => e
          puts "'#{e.message}'"
          if e.message == "item-not-found: " then
            domain.create_node("#{SLICE_PREFIX}/#{node}/#{SLICE_SUFFIX}")
            make_dispatcher(domain, "#{SLICE_PREFIX}/#{node}/#{SLICE_SUFFIX}")
          end
        end
        if @omf53
          begin
            make_dispatcher(domain, "#{SLICE_LEGACY_PREFIX}/#{node}/#{SLICE_SUFFIX}")
          rescue Exception => e
            puts "'#{e.message}'"
            if e.message == "item-not-found: " then
              domain.create_node("#{SLICE_LEGACY_PREFIX}/#{node}/#{SLICE_SUFFIX}")
              make_dispatcher(domain, "#{SLICE_LEGACY_PREFIX}/#{node}/#{SLICE_SUFFIX}")
            end
          end
        end
      end
    end
    make_dispatcher(domain, "#{SLICE_PREFIX}/system")
    make_dispatcher(domain, "#{SLICE_LEGACY_PREFIX}/system") if @omf53
  end

  def teardown_dispatchers
    @domains.each_value do |domain|
      @listeners[domain].each do |listener|
        listener.queue << :stop
        domain.unlisten(listener)
      end if @listeners[domain]
    end
    info "Waiting for XMPP dispatcher threads to finish..."
    @dispatcher_threads.each { |t| t.join }
    info "...all XMPP dispatcher threads finished"
  end

  def start
    first = true
    info "Starting XMPP request server: #{@server}"
    @connection.on_connect { setup_dispatchers }
    @connection.on_disconnect { teardown_dispatchers }
    setup_dispatchers
    begin
    rescue Exception => e
      error "While starting XMPP connections: #{e.message}"
    end
    @stopped = false
  end

  def stop
    info "Shutting down XMPP request server"
    sleep 1
    teardown_dispatchers
    info "...done"
    @stopped = true
  end

  def mount(service_class)
    debug("Mounting service class #{service_class}")

    service_name = service_class.serviceName
    service_calls = service_class.serviceCalls
    service_calls.each do |method, params|
      debug("Mounting service #{service_name}, method #{method}")
      service = @services[service_name] || Hash.new

      # arguments is a hash containing the key-value pairs of the
      # named arguments from the service call.  They have to be
      # matched with the arguments that the service method supports.
      service[method] = lambda do |arguments|
        argstr = arguments.collect { |k, v| "#{k} => '#{v}'" }.join(", ")
        debug "Service call:  '#{service_name}.#{method}(#{argstr})'"

        proc = params[:proc]
        if proc.nil?
          raise "Attempting to execute unimplemented service '#{service_name}.#{method}'"
        else
          p_list = params[:param_list] || []
          args = p_list.collect { |p| arguments[p.to_s] }
          result = proc.call(*args)
        end
      end
      @services[service_name] = service
    end
    @mounted_services[service_name] = service_class
  end
end # class XmppAggmgrServer


