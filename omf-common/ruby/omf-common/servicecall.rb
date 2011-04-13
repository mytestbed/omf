#
# Copyright 2006-2011 National ICT Australia (NICTA), Australia
#
# Copyright 2004-2011 WINLAB, Rutgers University, USA
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
# == Description
#
# The OMF::Services module provides an API into the available services
# and methods.  For instance, to call the 'allOffSoft' method on the
# 'cmc' service, the folowing ruby statement will look up the appropriate
# function to call and supply its arguments in the correct format:
#
#  OMF::Services.cmc.allOffSoft(...)
#
# The OMF::Services module takes care of the lookup process.  If it
#
# This architecture relies on the fact that all AM's must be
# self-describing

require 'singleton'
require 'rexml/document'
require 'omf-common/mobject'
require 'omf-common/servicecall/endpoint'
require 'omf-common/servicecall/xmpp'
require 'omf-common/servicecall/http'

module OMF
  module Services
    #
    # Route a service invocation to a method dispatcher.
    #
    # Args should be a hash.
    # args[:domain] can specify which pubsub domain the call should be routed to
    # args[:noreply] == true means the (multiple) remote responders should not send a reply
    #
    def Services.method_missing(m, args = nil)
      service = @@services[m] || Service.new(m)
      @@services[m] = service
      raise "Couldn't find a provider for service '#{m}' in OMF::Services module" if service.nil?
      service.modifiers = args
      service
    end

    def Services.add_domain(domainspec)
      type = domainspec[:type]
      uri = domainspec[:uri]
      raise "ServiceCall domainspec must have a :type (e.g. :http, :xmpp)" if type.nil?
      raise "ServiceCall domainspec must have a :uri (location of the service provider)" if uri.nil?
      @@domains[type] = @@domains[type] || []
      @@domains[type] << domainspec
    end

    class ServiceCallException < Exception; end
    class Timeout < ServiceCallException; end
    class ProtocolError < ServiceCallException; end
    class NoService < ServiceCallException; end
    class ConfigError < ServiceCallException; end
    class Error < ServiceCallException; end

    private

    @@domains = Hash.new
    @@services = Hash.new
    @@endpoints = Array.new

    def Services.domains
      @@domains
    end

    def Services.endpoints
      @@endpoints
    end

    #
    # A proto-service call.  It just encapsulates the name of the
    # service to be called and any modifiers that the caller
    # specified, and stores them.  It also implements method_missing
    # to hook the second stage of the service call (method
    # invocation).  The method_missing method implements the endpoint
    # lookup and actually makes the desired call.
    #
    class Service < MObject
      attr_reader :name
      attr_accessor :modifiers

      def initialize(name)
        @name = name
      end

      def method_missing(m, *args)
        if not modifiers.nil?
          tl = Endpoint.types.find_all { |t| modifiers.has_key? t }
          if tl.length > 1
            raise "Can't specify more than one domain modifier in service call:  found #{tl.join(', ')}"
          elsif tl.length == 1
            modifiers[:type] = tl[0]
            modifiers[:uri] = modifiers[tl[0]]
          end
        end

#        modifiers.each_pair { |k, v| puts "#{k} -> #{v}" } unless modifiers.nil?

        domain_hash = OMF::Services.domains

        # Find a domain first

        # TBD: implement a sort/filter to come up with a candidate
        # list, and evaluate each one in turn.  For now: just pick the
        # first one, trying :xmpp first and then :http :-)
        domain = domain_hash[:xmpp] || domain_hash[:http]
        domain = domain[0] unless domain.nil? or not domain.kind_of? Array or domain.empty?
        raise NoService, "No domain found for service call to #{name}.#{m}" if domain.nil?

        # Got a domain; now look for an endpoint to talk to on that domain.
        endpoints = Services.endpoints
        # First narrow down to all domains matching the type (http/xmpp/...) and uri
        if false
          endpoint = endpoints.find do |e|
            e.type == domain[:type] and
              e.domain == domain[:uri]
          end

          if endpoint.nil?
            endpoint = Endpoint.init(domain[:type], domain[:uri])
            Services.endpoints << endpoint
          end
        end

        endpoint = Endpoint.find(domain[:type], domain[:uri],
                                 modifiers, *args)

        endpoint.make_request(name, m, *args)
      end
    end # class Service
  end

  module ServiceCall

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
    def ServiceCall.add_domain(domain)
      OMF::Services::add_domain(domain)
    end

    # ----- Exception classes -----

    class ServiceCallException < Exception; end
    class Timeout < ServiceCallException; end
    class ProtocolError < ServiceCallException; end
    class NoService < ServiceCallException; end
    class ConfigError < ServiceCallException; end
    class Error < ServiceCallException; end
  end # module ServiceCall
end # module OMF
