module OmfCommon
  module DSL
    module Xmpp
      class MPConnection < OML4R::MPBase
        name :xmpp_connections
        param :time, :type => :int32
        param :jid, :type => :string
        param :operation, :type => :string
      end

      class MPPublished < OML4R::MPBase
        name :xmpp_published
        param :time, :type => :int32
        param :jid, :type => :string
        param :topic, :type => :string
        param :message, :type => :string
      end

      class MPReceived < OML4R::MPBase
        name :xmpp_received
        param :time, :type => :int32
        param :jid, :type => :string
        param :topic, :type => :string
        param :message, :type => :string
      end

      class MPSubscription < OML4R::MPBase
        name :xmpp_subscriptions
        param :time, :type => :int32
        param :jid, :type => :string
        param :operation, :type => :string
        param :topic, :type => :string
      end
    end
  end
end
