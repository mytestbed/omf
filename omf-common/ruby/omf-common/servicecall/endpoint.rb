#
# Copyright 2011 National ICT Australia (NICTA), Australia
#
# Copyright 2011 WINLAB, Rutgers University, USA
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
require 'rexml/document'
require 'omf-common/mobject'

module OMF
  module Services
    
    class EndpointException < Exception; end
    class UnknownEndpointException < EndpointException; end

    #
    # A service endpoint is a single communications endpoint that
    # offers AM services.  Examples:  an HTTP endpoint (specified by
    # a URL) or pubsub node on an XMPP server.
    #
    class Endpoint < MObject
      
      def self.create(type, opts)
        case type
        when :xmpp
          require 'omf-common/servicecall/xmpp'
          return XmppEndpoint.new(opts)
        when :http
          require 'omf-common/servicecall/http'
          return HttpEndpoint.new(opts)
        when :mock
        else
          raise EndpointException.new("Unknown enpoint type '#{type}'")
        end
      end
      
      # :domain -- the domain that this endpoint sits on (uri)
      # :type -- the type of domain that this endpoint sits on (:xmpp, :http)
      #attr_reader :domain, :type, :attributes

      @@types = Hash.new

      def initialize()
        # @services = nil
        # @domain = name
        # @type = type
        # @attributes = Hash.new
      end

      def send_request(service=nil, method=nil, *args)
        raise "#{self.class}#send_request must be implemented by subclasses"
      end

      def make_request(service, method, targets, domain, opts)
        send_request(service, method, targets, domain, opts)
        
        # Do we really need to all this checking? The HTTP transport
        # throws an exception anyway if we call a service or a method which doesn't exit.
        # The XMPP endpoint will most likely be quiet, but this can be for other reasons.
        #
         
        # service = service.to_s
        # method = method.to_s
        # if @services.nil?
          # get_service_list(service)
        # end
        # s = @services[service]
        # if s.nil?
          # raise NoService, "Tried to call unknown service #{service}"
        # else
          # get_service_method_list(service) if s == :pending
          # s = @services[service]
          # m = s[method]
          # if m.nil?
            # raise NoService, "Tried to call unknown method #{service}.#{method}"
          # else
            # if args.length == 1 and args[0].kind_of? Hash then
              # key_value_args = args
            # else
              # key_value_args = m.zip(args)
            # end
            # send_request(service, method, *key_value_args)
          # end
        # end
      end # make_request

      def get_service_list(target=nil)
        found = Queue.new
        @services = Hash.new if @services.nil?
        Thread.new {
          begin
            # Request with no service or method gets the full list
            xml = send_request { |r|
              # r must be a REXML::Element
              servs = r.elements.collect("serviceGroup") do |e|
                e.attributes["name"]
              end
              servs.each { |s|
                @services[s] = :pending
                found << :found if s == target
              }
            }
            found << :not_found
          rescue ServiceCallException => e
            error "Trying to get service list from domain '#{domain}':  #{e.message}"
            return nil
          else
#            services = []
#            if xml.kind_of? REXML::Element then
#              services = xml.elements.collect("serviceGroups/serviceGroup") do |e|
#                e.attributes["name"]
#              end
#            elsif xml.kind_of? Array then
#              xml.each do |el|
#                services += el.elements.collect("serviceGroup") { |e| e.attributes["name"] }
#              end
#            end
#            services.each { |s| @services[s] = :pending }
            found << :not_found
          end
        }
        found.pop
      end # get_service_list

      def get_service_method_list(service)
        if @services[service].nil?
          get_service_list(service)
        end
        begin
          xml = send_request(service) # Request with no method gets the method list
        rescue ServiceCallException => e
          error "Trying to get service list from domain '#{domain}': #{e.message}"
          return nil
        else
          @services[service] = Hash.new
          if not xml.nil?
            xml.elements.each("services/serviceGroup/service") do |e|
              name = e.attributes["name"]
              args = e.elements.collect("args/arg") { |a| a.attributes["name"] }
              @services[service][name] = args
            end
          else
            []
          end
        end
      end # get_service_method_list

      def has_service?(service)
        if @services.nil?
          get_service_list(service)
        end
        @services.has_key?(service) and not @services[service].nil?
      end

      def has_method?(service, method)
        if has_service?(service)
          if @services[service] == :pending
            get_service_method_list(service)
          end
          s = @services[service]
          s.has_key?(method) and not s[method].nil?
        else
          false
        end
      end
      
      #
      # Return true if this instance of an Endpoint subclass should service
      # the given query.
      #
      def match?(type, uri, *args)
        raise "Subclasses of OMF::Services::Endpoint must implement match? method"
      end

      # #
      # # Initialize a new endpoint of given type at given uri.  *args
      # # should be the arguments to a service call that needs to be
      # # made to the eventual endpoint.
      # #
      # def self.init(type, uri, *args)
        # raise "Unknown ServiceDomain type #{type}" if @@types[type].nil?
        # @@types[type].new(type, uri, *args)
      # end
# 
      # def self.register(type)
        # @@types[type] = self
      # end
# 
      # @@endpoints = Hash.new
# 
      # #
      # # Find an endpoint to satisfy a request.  The request must be
      # # satisfied by an endpoint on a domain of the given type and at
      # # the specified uri; but if the modifiers suggest a different
      # # type and uri, look for one matching those instead.
      # #
      # def self.find(type, uri, modifiers, *args)
        # alt_type = nil
        # alt_uri = nil
        # if not modifiers.nil?
          # if not modifiers[:type].nil?
            # alt_type = modifiers[:type]
            # alt_uri = modifiers[:uri]
          # else
            # alt_type = @@types.find { |t| modifiers.has_key? t }
            # alt_uri = modifiers[alt_type] unless alt_type.nil?
          # end
        # end
        # type = alt_type || type
        # uri = alt_uri || uri
        # endpoints = @@endpoints[type]
        # if endpoints.nil?
          # # If no endpoint of the right type, instantiate a new one
          # endpoint = self.init(type, uri, *args)
          # @@endpoints[type] = [endpoint]
          # endpoint
        # else
          # # Otherwise, search for one that matches the query
          # endpoints = @@endpoints[type]
          # endpoint = endpoints.find { |e| e.match?(type, uri, *args) }
          # if endpoint.nil?
            # endpoint = self.init(type, uri, *args)
          # end
          # endpoints << endpoint
          # endpoint
        # end
      # end # self.find
# 
      # def self.types
        # @@types.keys
      # end
    end # class Endpoint
  end # module Services
end # module OMF
