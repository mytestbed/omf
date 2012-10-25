module OmfCommon
  module DSL
    module Xmpp
      class MPConnection < OML4R::MPBase
        name :xmpp_connections
        param :time, :type => :double
        param :jid, :type => :string
        param :operation, :type => :string
      end

      class MPPublished < OML4R::MPBase
        name :xmpp_published
        param :time, :type => :double
        param :jid, :type => :string
        param :topic, :type => :string
        param :xml_stanza, :type => :string
      end

      class MPReceived < OML4R::MPBase
        name :xmpp_received
        param :time, :type => :double
        param :jid, :type => :string
        param :topic, :type => :string
        param :xml_stanza, :type => :string
      end

      class MPSubscription < OML4R::MPBase
        name :xmpp_subscriptions
        param :time, :type => :double
        param :jid, :type => :string
        param :operation, :type => :string
        param :topic, :type => :string
      end
    end
  end
end
