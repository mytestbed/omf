
require 'rubygems'
require 'xmpp4r'
require 'omf-common/xmpp'

#Jabber::debug = true

module OMF
  module ServiceCall
    module XMPP
      @@connection = nil
      def XMPP.new_xmpp_domain(domainspec)
        pubsub_domain = domainspec[:uri]

        if @@connection.nil?
          # create the gateway connection
          gw = domainspec[:gateway] || pubsub_domain
          user = domainspec[:user]
          password = domainspec[:password]
          @@connection = XMPP::Connection.new(gw, user, password)
        end

        if not @@connection.connected?
          begin
            @@connection.connect
            if not @@connection.connected?
              raise ServiceCall::NoService, "Attemping to connect to XMPP server failed"
            end
          rescue XmppError => e
            raise ServiceCall::NoService, e.message
          end
        end

        domain = XMPP::PubSub::Domain.new(@@connection, pubsub_domain)
        domain.request_subscriptions

        lambda do |service, *args|
          service = service || ""
          xmpp_call(domain, service, *args)
        end
      end

      def XMPP.xmpp_call(domain, service, uri, *args)

      end
    end
  end # module ServiceCall
end # module OMF

def run
end

run if __FILE__ == $PROGRAM_NAME
