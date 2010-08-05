
# A service call is a generalized function call.  This module
# represents service calls as a closure whose first parameter is a
# OMF::ServiceCall::Uri.  The Uri is not a strictly parsed URI in the
# IETF sense, but a multi-component address that can be turned into a
# concrete URI at the last minute.  The URI's can be built up in a
# chained fashion using the '+' operator.
#
# This generalized function call or "genfunc" is a closure over a URI,
# and a new, more specific genfunc can be created by closing over
# another genfunc.  e.g. in pseudo-code:
#
#  def mkg2(uri)
#     lambda do |x, *args| { g1(uri + x, *args) }
#  end
#
# mkg2 creates a new 'g2' genfunc based on the genfunc 'g1'.
#
# We use three levels of genfuncs: domain, service, method.  The
# 'domain' genfunc is a generic interface to a specific service
# provider.  If it is an HTTP endpoint then its URI is an HTTP domain
# URI, such as http://norbit.npc.nicta.com.au:5052.  The 'service'
# genfunc is a closure over a specific domain genfunc for a service
# provider.  e.g. the CMC service is a genfunc whose URI expands to
# http://norbit.npc.nicta.com.au/cmc.  A 'method' genfunc is a closure
# over a particular service genfun.
#
# The OMF::Services module provides an API into the available services
# and methods.  For instance, to call the 'allOffSoft' method on the
# 'cmc' service, the folowing ruby statement will look up the appropriate
# genfunc to call and supply its arguments in the correct format:
#
#  OMF::Services.cmc.allOffSoft(...)
#
# The OMF::Services module takes care of the lookup process.  If it
# already has a cached genfunc to provide the service/method then it
# retrieves it and executes the call; otherwise it does a search of
# known domains to find out which one (if any) provides it, creates
# and caches an appropriate genfunc, and then executes the call if the
# service was found.  If no domain is found offering the service, then
# an exception is raised which the caller must handle.
#
# This architecture relies on the fact that all AM's must be
# self-describing: the domain genfunc returns a list of services
# available at the domain when invoked with an empty URI parameter,
# and each service genfunc returns a list of methods (together with
# parameters) when invoked with an empty URI parameter.
#

require 'singleton'
require 'rexml/document'
require 'omf-common/mobject'
require 'omf-common/servicecall/xmpp'
require 'omf-common/servicecall/http'

module OMF

  module Services
    def Services.method_missing(m, *args)
      service = ServiceCall::Dispatch.instance.lookup_service(m)
      raise "Couldn't find a provider for service '#{m}' in OMF::Services module" if service.nil?
      service
    end
  end

  module ServiceCall

    def ServiceCall.add_domain(domain)
      Dispatch.instance.add_domain(domain)
    end

    # ----- Exception classes -----

    class ServiceCallException < Exception; end
    class Timeout < ServiceCallException; end
    class ProtocolError < ServiceCallException; end
    class NoService < ServiceCallException; end
    class ConfigError < ServiceCallException; end
    class Error < ServiceCallException; end

    private

    class Dispatch < MObject
      include Singleton

      @domains = Array.new
      @services = Hash.new

      #
      # Add a new service call domain.  The +domainspec+ is a Hash
      # that specifies the name, the type of domain, and any other
      # required parameters.  For instance, for an HTTP domain, we use:
      #
      # add_domain(:type => :http,
      #            :uri  => "http://norbit.nicta.com.au:5053")
      #
      # For an XMPP domain, use:
      #
      # add_domain(:type => :xmpp,
      #            :uri  => "norbit.npc.nicta.com.au",
      #            :user => "joe",
      #            :password => "123")
      #
      # The :type key must be present in the Hash, or an exception
      # will be raised.  It is used to dispatch the domain creation to
      # the relevant protocol API.
      #
      # [domainspec] :: Hash
      def add_domain(domainspec)
        @domains = @domains || []
        type = domainspec[:type]
        uri = domainspec[:uri]
        raise "ServiceCall domainspec must have a :type (e.g. :http, :xmpp)" if type.nil?
        raise "ServiceCall domainspec must have a :uri (location of the service provider)" if uri.nil?
        domainspec[:uri] = Uri.new(uri)
        dom = case type
              when :http then HTTP.new_http_domain(domainspec)
              when :xmpp then XMPP.new_xmpp_domain(domainspec)
              else raise "Unknown ServiceCall domain type '#{type}'"
              end
        @domains << dom
        dom
      end

      # [name] :: String
      def lookup_service(name)
        @services = @services || Hash.new
        service = @services[name]
        if service.nil?
          service = find_service(name)
        end
        service
      end

      # [name] ::String
      def find_service(name)
        @domains.each do |dom|
          list = get_service_list(dom)
          if list.include?(name.to_s)
            return Service.new(name, new_service_proc(dom, Uri.new(name)))
          end
        end
        nil
      end

      # [domain] :: domain Proc
      def get_service_list(domain)
        xml = domain.call('')
        xml.elements.collect("serviceGroups/serviceGroup") { |e| e.attributes["name"] }
      end

      # [service] :: service Proc
      def get_service_method_list(service)
        xml = service.call('')
        if not xml.nil?
          xml.elements.collect("services/serviceGroup/service") do |e|
            name = e.attributes["name"]
            args = e.elements.collect("args/arg") { |a| a.attributes["name"] }
            [name] + args
          end
        else
          []
        end
      end

      private

      # [domain] :: domain Proc
      # [service] :: Uri
      def new_service_proc(domain, service)
        lambda do |method, *args|
          method = method || ''
          domain.call(service + method, *args)
        end
      end

      # --------- Supporting Classes -----------

      class Uri
        @components = nil

        attr_reader :components

        def initialize(uri)
          case uri
          when String then @components = [uri]
          when Array  then @components = uri
          when Symbol then @components = [uri.to_s]
          else
            raise "Can't make Uri from #{uri} (#{uri.class()})"
          end
        end

        def + (component)
          Uri.new(@components + [component.to_s])
        end

        def to_s
          @components.each { |c| c.to_s }.join("/")
        end
      end # class Uri

      class Service
        @proc = nil
        @methods = nil
        @signatures = nil

        def initialize(name, proc)
          @name = name
          @proc = proc
          @methods = Hash.new
          @signatures = Hash.new
          methods = Dispatch.instance.get_service_method_list(@proc)
          methods.each do |method|
            name = method[0]
            parameters = method[1..-1]
            mkmethod(name, parameters)
          end
        end

        def mkmethod(name, parameters)
          @signatures[name] = parameters
          @methods[name] = lambda do |*args|
            exec(name, *parameters.zip(args))
          end
        end

        def exec(method, *args)
          @proc.call(Uri.new(method), *args)
        end

        def method_missing(m, *args)
          if @methods.has_key?(m.to_s)
            @methods[m.to_s].call(*args)
          else
            raise "Service #{@name} has no method '#{m.to_s}'"
          end
        end

        def inspect
          puts "---- Service Description ----"
          puts "Name = #{@name}"
          puts "Methods = "
          @signatures.each_pair { |m, a| puts "  #{@name}.#{m}(#{a.join(', ')})"  }
          puts "---- End Service Description ----"
        end
      end # class Uri
    end # class Dispatch
  end # module ServiceCall
end # module OMF
