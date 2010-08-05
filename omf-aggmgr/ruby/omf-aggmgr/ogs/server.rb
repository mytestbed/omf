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
require 'omf-common/omfProtocol'
require 'omf-common/xmpp'

class AggmgrServer < MObject

  @@mutex = nil

  attr_accessor :server

  def initialize(params)
    super(self.class)
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
    @@mutex = Mutex.new if @@mutex.nil?
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
end

class HttpAggmgrServer < AggmgrServer
  @port = nil
  @config_dir = nil

  def initialize(params)
    debug(:gridservices, "Initializing HTTP server manager")
    http_params = params[:http]
    @port = http_params[:port] || DEF_WEB_PORT
    @config_dir = params[:configDir]
    @mounted_services = {}
    @server = HTTPServer.new(:Port => @port || DEF_WEB_PORT,
                             :Logger => Log4r::Logger.new("#{MObject.logger.fullname}::web"))

    path = File.dirname(@config_dir) + "/favicon.ico"
    @server.mount("/favicon.ico", HTTPServlet::FileHandler, path) {
      raise HTTPStatus::NotFound, "#{path} not found."
    }
    @server.mount_proc('/') do |req, res|
      res['Content-Type'] = "text/xml"
      body = [%{<?xml version='1.0'?><serviceGroups>}]
      @mounted_services.each do |path, service|
        info = service.info
        name = service.serviceName
        body << "<serviceGroup path='#{path}' name='#{name}'><info>#{info}</info></serviceGroup>"
      end
      body << "</serviceGroups>"
      res.body = body.to_s
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
    @server.start
  end

  def stop
    @server.shutdown
  end

  def mount(service_class)
    debug " Mounting #{service_class}"
    service_name = service_class.serviceName
    service_calls = service_class.serviceCalls
    service_calls.each do |name, params|
      mount_point = "/#{service_name}/#{name}"
      debug "Mounting #{mount_point}"
      @server.mount_proc(mount_point) do |req, res|
        proc = params[:proc]
        if proc.nil? then
          raise HTTPStatus::NotImplemented, "No support for service '#{service_name}', subservice '#{name}'"
        end

        p_list = params[:param_list] || []
        args = p_list.collect { |p| req.query[p.to_s] }
        result = nil
        @@mutex.synchronize { result = proc.call(*args) }

        if result == true then
          HttpAggmgrServer.response_ok(res)
        elsif result.kind_of? REXML::Element then
          HttpAggmgrServer.response_xml(res, result)
        else
          HttpAggmgrServer.response_plain_text(res, result.to_s)
        end
        p res.status
        p res.body
        p res.header
        p res.reason_phrase
        p res.http_version
      end
    end

    @server.mount_proc("/#{service_name}") do |req, res|
      res['ContentType'] = "text/xml"
      ss = StringIO.new()
      ss.write("<?xml version='1.0'?>\n")
      doc = REXML::Document.new
      root = doc.add(REXML::Element.new("services"))
      el = service_class.to_xml(root)
      el.attributes['prefix'] = "/#{service_name}"
      formatter = REXML::Formatters::Default.new
      formatter.write(doc,ss)
      res.body = ss.string
    end

    @mounted_services[service_name] = service_class
  end

end

class XmppAggmgrServer < AggmgrServer

  include OmfProtocol

  def initialize(params)
    debug "Initializing XMPP PubSub AM server"
    xmpp_params = params[:xmpp]
    @server = xmpp_params[:server]
    @user = xmpp_params[:user]
    @password = xmpp_params[:password]
    @connection = OMF::XMPP::Connection.new(@server, @user, @password)
    debug "Connecting to XMPP PubSub server '#{@server}' with user '#{@user}'"
    @connection.connect
    debug "...connected"

    # We need to talk to at least one pubsub domain -- use the local
    # gateway as the default domain.  In future, we'll need to talk to
    # multiple domains, but the architecture isn't settled yet, so we
    # leave it at just the local domain for the moment.
    @domains = Hash.new
    @domains[@server] = OMF::PubSub::Domain.new(@connection, @server)
    @domains.each_value do |domain|
      # Only add the system node to start with.
      make_dispatcher(domain, "/OMF/system")
    end
  end

  def start
    @server.start
  end
  def stop
    @server.stop
  end

  def mount(service_class)
    debug("Mounting service class #{service_class}")

    service_name = service_class.serviceName
    service_calls = service_class.serviceCalls
    service_calls.each do |name, params|
      debug("Mounting service #{service_name}, subservice #{name}")
      @server.mount_proc(service_name, name) do |server, command|
        puts "Received service call with XML:"
        puts command.to_s

        proc = params[:proc]
        if proc.nil? then
          raise HTTPStatus::NotImplemented, "No support for service '#{service_name}', subservice '#{name}'"
        end

        node = system_node?(command.pubsub_node)

        if not node.nil? then
          command.name = node
        end

        p_list = params[:param_list] || []
        args = p_list.collect { |p| command.attributes[p.to_s] }
        result = proc.call(*args)

        response_type = (command.cmdType.to_s + "_REPLY").to_sym
        res = server.new_command(response_type)
      end
    end
  end
end


